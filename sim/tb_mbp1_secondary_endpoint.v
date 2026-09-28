`timescale 1ns/1ps
module tb_mbp1_secondary_endpoint;
reg clk=0, rst=1, phy_link=1;
always #5 clk=~clk;
reg [7:0] rx_data=0;
reg rx_valid=0;
reg [15:0] rx_length=0;
wire tx_request, tx_valid, peer_alive, heartbeat_pulse;
wire display_pulse, diagnostic_pulse;
wire [7:0] tx_data;
wire [15:0] tx_length, crc_error_count, drop_count;
wire [127:0] heartbeat_data, diagnostic_data;
wire [95:0] display_data;
wire control_ready, control_done;
wire [7:0] control_result;
reg control_request=0;
reg [7:0] control_type=0;
reg [63:0] control_payload=0;
reg tx_ack=0;
integer i, heartbeat_seen=0, display_seen=0, diagnostic_seen=0;
integer tx_seen=0;
integer tx_index=0, ack_seen=0, query_seen=0;
integer control_done_seen=0;
reg [31:0] control_seq;
reg tx_valid_d=0;
reg [7:0] packet [0:63];
reg [7:0] output_bytes [0:63];
reg [15:0] crc;

mbp1_secondary_endpoint #(.CLOCKS_PER_MS(100)) dut (
    .clk(clk), .rst(rst), .phy_link(phy_link),
    .local_boot_id(32'hface1234), .rx_data(rx_data),
    .rx_valid(rx_valid), .rx_length(rx_length),
    .tx_ready(1'b1), .tx_ack(tx_ack),
    .tx_request(tx_request), .tx_data(tx_data),
    .tx_valid(tx_valid), .tx_length(tx_length),
    .peer_alive(peer_alive), .heartbeat_pulse(heartbeat_pulse),
    .heartbeat_data(heartbeat_data), .display_pulse(display_pulse),
    .display_data(display_data), .diagnostic_pulse(diagnostic_pulse),
    .diagnostic_data(diagnostic_data), .crc_error_count(crc_error_count),
    .drop_count(drop_count), .control_request(control_request),
    .control_type(control_type), .control_payload(control_payload),
    .control_ready(control_ready), .control_done(control_done),
    .control_result(control_result)
);
always @(negedge clk) tx_ack=tx_request;
always @(posedge clk) begin
    if (heartbeat_pulse) heartbeat_seen=heartbeat_seen+1;
    if (display_pulse) display_seen=display_seen+1;
    if (diagnostic_pulse) diagnostic_seen=diagnostic_seen+1;
    if (control_done) control_done_seen=control_done_seen+1;
    if (tx_valid) begin
        if (!tx_valid_d) tx_index=0;
        else tx_index=tx_index+1;
        if (tx_index==3 && tx_data==8'h04) ack_seen=ack_seen+1;
        if (tx_index==3 && tx_data==8'h03) query_seen=query_seen+1;
        if (tx_seen<64) output_bytes[tx_seen]=tx_data;
        tx_seen=tx_seen+1;
    end
    tx_valid_d=tx_valid;
end
function [15:0] crc_byte;
    input [15:0] prior;
    input [7:0] value;
    reg [15:0] c;
    integer b;
    begin
        c=prior ^ {value,8'd0};
        for(b=0;b<8;b=b+1) c=c[15] ? ((c<<1)^16'h1021) : (c<<1);
        crc_byte=c;
    end
endfunction
task inject;
    input [7:0] msg_type, flags;
    input [31:0] seq, boot;
    input integer n;
    input [127:0] payload;
    integer j;
    begin
        packet[0]=8'h4d; packet[1]=8'h42; packet[2]=8'h01;
        packet[3]=msg_type; packet[4]=flags; packet[5]=8'h14;
        packet[6]=0; packet[7]=n;
        for(j=0;j<4;j=j+1) begin
            packet[8+j]=seq >> (24-8*j);
            packet[12+j]=boot >> (24-8*j);
            packet[16+j]=0;
        end
        for(j=0;j<n;j=j+1) packet[20+j]=payload >> (120-8*j);
        crc=16'hffff;
        for(j=0;j<20+n;j=j+1) crc=crc_byte(crc,packet[j]);
        packet[20+n]=crc[15:8]; packet[21+n]=crc[7:0];
        @(negedge clk); rx_length=22+n;
        for(j=0;j<22+n;j=j+1) begin
            rx_valid=1; rx_data=packet[j];
            @(negedge clk);
        end
        rx_valid=0;
        repeat(5) @(negedge clk);
    end
endtask
task inject_bad_crc;
    integer j;
    begin
        packet[0]=8'h4d; packet[1]=8'h42; packet[2]=8'h01;
        packet[3]=8'h02; packet[4]=0; packet[5]=8'h14;
        packet[6]=0; packet[7]=16;
        for(j=8;j<20;j=j+1) packet[j]=0;
        for(j=20;j<36;j=j+1) packet[j]=8'hff;
        packet[36]=0; packet[37]=0;
        @(negedge clk); rx_length=38;
        for(j=0;j<38;j=j+1) begin
            rx_valid=1; rx_data=packet[j];
            @(negedge clk);
        end
        rx_valid=0;
        repeat(5) @(negedge clk);
    end
endtask
initial begin
    repeat(4) @(negedge clk); rst=0;
    wait(tx_seen==34);
    if (output_bytes[3]!=8'h01 || output_bytes[20]!=8'h02 ||
        output_bytes[21]!=8'h02 || output_bytes[22]!=8'h01 ||
        output_bytes[23]!=8'h01) $fatal(1,"proactive HELLO");
    inject(8'h02,0,32'd10,32'h12345678,16,
           128'h0102ff000000008000000000000023f3);
    if (heartbeat_seen!=1 || !peer_alive ||
        heartbeat_data!=128'h0102ff000000008000000000000023f3)
        $fatal(1,"full heartbeat decode");
    inject(8'h02,0,32'd10,32'h12345678,16,128'hffffffffffffffffffffffffffffffff);
    if (heartbeat_seen!=1) $fatal(1,"duplicate heartbeat");
    inject_bad_crc();
    if (heartbeat_seen!=1 || crc_error_count!=1)
        $fatal(1,"bad CRC changed state");
    inject(8'h02,0,32'd11,32'h12345678,15,
           128'hffffffffffffffffffffffffffffffff);
    if (heartbeat_seen!=1) $fatal(1,"short heartbeat changed state");
    inject(8'h16,0,32'd9,32'h12345678,12,
           128'hff030203040200ff0000000000000000);
    if (display_seen!=1 || display_data!=96'hff030203040200ff00000000)
        $fatal(1,"display status decode");
    inject(8'h31,0,32'd8,32'h12345678,16,
           128'h010302010f0700000000000000000000);
    if (diagnostic_seen!=1 || diagnostic_data[127:120]!=8'h01)
        $fatal(1,"diagnostic decode");
    if (!control_ready) $fatal(1,"control never ready");
    @(negedge clk); control_request=1; control_type=8'h13;
    control_payload=64'h0201000000000000;
    @(negedge clk); control_request=0;
    control_seq=dut.active_control_seq;
    wait(dut.control_attempts==1);
    inject(8'h16,0,32'd10,32'h12345678,12,
           128'h02030203040200ff0000000000000000);
    if (control_done_seen!=0) $fatal(1,"status before ACK must wait");
    inject(8'h04,8'h02,32'd12,32'h12345678,8,
           {control_seq,8'h13,8'd0,16'd0,64'd0});
    if (control_done_seen!=1 || control_result!=0 || !control_ready)
        $fatal(1,"ACK after status did not complete");
    @(negedge clk); control_request=1; control_type=8'h13;
    control_payload=64'h0101000000000000;
    @(negedge clk); control_request=0;
    control_seq=dut.active_control_seq;
    wait(dut.control_attempts==2);
    if (dut.send_seq!=control_seq || dut.send_flags!=8'h05)
        $fatal(1,"retry must preserve seq and use RETRY flag");
    inject(8'h04,8'h02,32'd13,32'h12345678,8,
           {control_seq,8'h13,8'd4,16'd0,64'd0});
    if (control_done_seen!=2 || control_result!=4 || !control_ready)
        $fatal(1,"BUSY must unlock control");
    inject(8'h12,8'h01,32'd11,32'h12345678,8,
           128'h02010000000000000000000000000000);
    repeat(500) @(negedge clk);
    if (ack_seen<1 || query_seen<1)
        $fatal(1,"ACK/telemetry transmit");
    $display("PASS tb_mbp1_secondary_endpoint");
    $finish;
end
initial begin #1000000; $fatal(1,"timeout"); end
endmodule
