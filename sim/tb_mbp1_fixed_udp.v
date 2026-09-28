`timescale 1ns/1ps
module tb_mbp1_fixed_udp;
parameter SECONDARY = 0;
reg clk=0, rst=1;
always #4 clk=~clk;
reg [7:0] rx_data=0;
reg rx_valid=0, rx_sof_n=1, rx_eof_n=1;
wire rx_ready_n;
wire [7:0] tx_data, app_rx_data;
wire tx_valid_n, tx_sof_n, tx_eof_n, app_rx_valid, app_tx_ready;
wire [15:0] app_rx_length;
reg tx_ready_n=0, app_tx_request=0, app_tx_valid=0;
integer tx_cycle=0;
always @(negedge clk) begin
    tx_cycle=tx_cycle+1;
    tx_ready_n=(tx_cycle%7)==0;
end
reg [7:0] app_tx_data=0;
reg [15:0] app_tx_length=22;
wire app_tx_ack;
integer i, received=0, sent=0, frames=0;
reg [7:0] frame [0:127];

mbp1_fixed_udp #(
    .OUR_MAC(SECONDARY ? 48'h02_48_58_34_20_02 : 48'h02_48_58_34_20_01),
    .OUR_IP(SECONDARY ? 32'hc0a80a02 : 32'hc0a80a01),
    .PEER_IP(SECONDARY ? 32'hc0a80a01 : 32'hc0a80a02),
    .PEER_MAC(48'h02_48_58_34_20_01), .FIXED_PEER(SECONDARY)
) dut (
    .clk(clk), .rst(rst), .mac_rx_data(rx_data), .mac_rx_valid(rx_valid),
    .mac_rx_sof_n(rx_sof_n), .mac_rx_eof_n(rx_eof_n),
    .mac_rx_ready_n(rx_ready_n), .mac_tx_data(tx_data),
    .mac_tx_valid_n(tx_valid_n), .mac_tx_sof_n(tx_sof_n),
    .mac_tx_eof_n(tx_eof_n), .mac_tx_ready_n(tx_ready_n),
    .app_rx_data(app_rx_data), .app_rx_valid(app_rx_valid),
    .app_rx_length(app_rx_length), .app_tx_request(app_tx_request),
    .app_tx_data(app_tx_data), .app_tx_valid(app_tx_valid),
    .app_tx_length(app_tx_length), .app_tx_ready(app_tx_ready),
    .app_tx_ack(app_tx_ack)
);

task byte_in;
    input [7:0] b;
    input start_byte, end_byte;
    begin
        @(negedge clk);
        rx_data=b; rx_valid=1; rx_sof_n=!start_byte; rx_eof_n=!end_byte;
    end
endtask

always @(posedge clk) begin
    if (!tx_valid_n && !tx_ready_n) begin
        if (!tx_sof_n) sent=0;
        frame[sent]=tx_data;
        sent=sent+1;
        if (!tx_eof_n) frames=frames+1;
    end
    if (app_rx_valid) begin
        if (app_rx_data !== 8'h4d + received) $fatal(1,"RX payload %d",received);
        if (app_rx_length !== 4) $fatal(1,"RX length");
        received=received+1;
    end
end

initial begin
    repeat(5) @(negedge clk); rst=0;
    if (SECONDARY) begin
        // The secondary must send HELLO before receiving ARP or UDP.
        wait(app_tx_ready);
        @(negedge clk); app_tx_request=1;
        wait(app_tx_ack);
        @(negedge clk); app_tx_request=0;
        for(i=0;i<22;i=i+1) begin
            app_tx_valid=1; app_tx_data=i;
            @(negedge clk);
        end
        app_tx_valid=0;
        wait(frames==1);
        if (frame[0]!=8'h02 || frame[5]!=8'h01 ||
            frame[11]!=8'h02 || frame[29]!=8'h02 || frame[33]!=8'h01)
            $fatal(1,"proactive secondary UDP");
    end
    // Windows-style ARP request for 192.168.10.1 from 192.168.10.2.
    for(i=0;i<60;i=i+1) begin
        case(i)
            0,1,2,3,4,5: byte_in(8'hff,i==0,i==59);
            6: byte_in(8'h02,0,0); 7: byte_in(8'h11,0,0);
            8: byte_in(8'h22,0,0); 9: byte_in(8'h33,0,0);
            10: byte_in(8'h44,0,0); 11: byte_in(8'h55,0,0);
            12: byte_in(8'h08,0,0); 13: byte_in(8'h06,0,0);
            15: byte_in(8'h01,0,0); 16: byte_in(8'h08,0,0);
            18: byte_in(8'h06,0,0); 19: byte_in(8'h04,0,0);
            21: byte_in(8'h01,0,0);
            22: byte_in(8'h02,0,0); 23: byte_in(8'h11,0,0);
            24: byte_in(8'h22,0,0); 25: byte_in(8'h33,0,0);
            26: byte_in(8'h44,0,0); 27: byte_in(8'h55,0,0);
            28: byte_in(8'hc0,0,0); 29: byte_in(8'ha8,0,0);
            30: byte_in(8'h0a,0,0); 31: byte_in(SECONDARY ? 8'h01 : 8'h02,0,0);
            38: byte_in(8'hc0,0,0); 39: byte_in(8'ha8,0,0);
            40: byte_in(8'h0a,0,0); 41: byte_in(SECONDARY ? 8'h02 : 8'h01,0,0);
            default: byte_in(8'h00,0,i==59);
        endcase
    end
    @(negedge clk); rx_valid=0; rx_sof_n=1; rx_eof_n=1;
    wait(frames==(SECONDARY ? 2 : 1));
    if (sent!=60 || frame[20]!=0 || frame[21]!=2 || frame[0]!=8'h02 ||
        frame[1]!=8'h11 || frame[11]!=(SECONDARY ? 8'h02 : 8'h01) ||
        frame[41]!=(SECONDARY ? 8'h01 : 8'h02)) $fatal(1,"ARP reply");
    // IPv4/UDP: source 192.168.10.2:5000, dest 192.168.10.1:5000.
    for(i=0;i<46;i=i+1) begin
        case(i)
            6: byte_in(8'h02,i==0,i==45);
            7: byte_in(8'h11,0,0); 8: byte_in(8'h22,0,0);
            9: byte_in(8'h33,0,0); 10: byte_in(8'h44,0,0);
            11: byte_in(8'h55,0,0);
            12: byte_in(8'h08,0,0); 13: byte_in(8'h00,0,0);
            14: byte_in(8'h45,0,0); 20: byte_in(8'h40,0,0);
            22: byte_in(8'h40,0,0); 23: byte_in(8'h11,0,0);
            26: byte_in(8'hc0,0,0); 27: byte_in(8'ha8,0,0);
            28: byte_in(8'h0a,0,0); 29: byte_in(SECONDARY ? 8'h01 : 8'h02,0,0);
            30: byte_in(8'hc0,0,0); 31: byte_in(8'ha8,0,0);
            32: byte_in(8'h0a,0,0); 33: byte_in(SECONDARY ? 8'h02 : 8'h01,0,0);
            34,36: byte_in(8'h13,0,0); 35,37: byte_in(8'h88,0,0);
            39: byte_in(8'h0c,0,0);
            42,43,44,45: byte_in(8'h4d+i-42,0,i==45);
            default: byte_in(8'h00,i==0,i==45);
        endcase
    end
    @(negedge clk); rx_valid=0; rx_sof_n=1; rx_eof_n=1;
    repeat(3) @(negedge clk);
    if(received!=4) $fatal(1,"RX count %d",received);
    wait(app_tx_ready);
    @(negedge clk); app_tx_request=1;
    wait(app_tx_ack);
    @(negedge clk); app_tx_request=0;
    for(i=0;i<22;i=i+1) begin
        app_tx_valid=1; app_tx_data=i;
        @(negedge clk);
    end
    app_tx_valid=0;
    wait(frames==(SECONDARY ? 3 : 2));
    if (frame[12]!=8'h08 || frame[13]!=0 || frame[16]!=0 ||
        frame[17]!=50 || frame[38]!=0 || frame[39]!=30 ||
        frame[24]!=8'ha5 || frame[25]!=8'h67 ||
        frame[42]!=0 || frame[63]!=21 ||
        frame[29]!=(SECONDARY ? 8'h02 : 8'h01) ||
        frame[33]!=(SECONDARY ? 8'h01 : 8'h02)) $fatal(1,"UDP TX");
    wait(app_tx_ready);
    @(negedge clk); app_tx_length=38; app_tx_request=1;
    wait(app_tx_ack);
    @(negedge clk); app_tx_request=0;
    for(i=0;i<38;i=i+1) begin
        app_tx_valid=1; app_tx_data=i;
        @(negedge clk);
    end
    app_tx_valid=0;
    wait(frames==(SECONDARY ? 4 : 3));
    if (sent!=80 || frame[17]!=66 || frame[39]!=46 || frame[79]!=37)
        $fatal(1,"38-byte MBP1 UDP TX");
    $display("PASS tb_mbp1_fixed_udp");
    $finish;
end
initial begin #50000; $fatal(1,"timeout"); end
endmodule
