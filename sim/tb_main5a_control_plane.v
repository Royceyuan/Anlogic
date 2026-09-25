`timescale 1ns / 1ps

module tb_main5a_control_plane;
reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;

wire mdc;
wire mdio_drive_low;
wire [15:0] phy_id1;
wire [15:0] phy_id2;
wire [15:0] phy_status;
wire mdio_sample_valid;
reg mdio_i;
reg [15:0] mdio_response;

mdio_clause22_monitor #(
    .CLK_HZ(100), .MDC_HZ(10), .POLL_GAP_CYCLES(4)
) u_mdio (
    .clk(clk), .rst(rst), .mdio_i(mdio_i), .mdc(mdc),
    .mdio_drive_low(mdio_drive_low), .phy_id1(phy_id1),
    .phy_id2(phy_id2), .phy_status(phy_status),
    .sample_valid(mdio_sample_valid)
);

always @* begin
    case (u_mdio.register_index)
        2'd0: mdio_response = 16'h001c;
        2'd1: mdio_response = 16'hc915;
        default: mdio_response = 16'hac00;
    endcase
    if ((u_mdio.bit_index >= 7'd48) && (u_mdio.bit_index <= 7'd63))
        mdio_i = mdio_response[63-u_mdio.bit_index];
    else
        mdio_i = 1'b1;
end

reg [7:0] rx_data = 8'd0;
reg rx_valid = 1'b0;
reg [15:0] rx_length = 16'd4;
reg tx_ready = 1'b1;
reg tx_ack = 1'b0;
wire tx_request;
wire [7:0] tx_data;
wire tx_valid;
wire [15:0] tx_length;
integer sample_count = 0;
integer echo_count = 0;

udp_echo_buffer u_echo (
    .clk(clk), .rst(rst), .rx_data(rx_data), .rx_valid(rx_valid),
    .rx_length(rx_length), .tx_ready(tx_ready), .tx_ack(tx_ack),
    .tx_request(tx_request), .tx_data(tx_data), .tx_valid(tx_valid),
    .tx_length(tx_length)
);

always @(posedge clk) begin
    if (mdio_sample_valid)
        sample_count <= sample_count + 1;
    if (tx_valid) begin
        case (echo_count)
            0: if (tx_data !== 8'h11) $fatal(1, "echo byte 0 mismatch: %02x", tx_data);
            1: if (tx_data !== 8'h22) $fatal(1, "echo byte 1 mismatch: %02x", tx_data);
            2: if (tx_data !== 8'h33) $fatal(1, "echo byte 2 mismatch: %02x", tx_data);
            3: if (tx_data !== 8'h44) $fatal(1, "echo byte 3 mismatch: %02x", tx_data);
            default: $fatal(1, "too many echo bytes");
        endcase
        echo_count <= echo_count + 1;
    end
end

task send_byte;
    input [7:0] value;
    begin
        rx_data = value;
        rx_valid = 1'b1;
        @(negedge clk);
    end
endtask

initial begin
    repeat (3) @(negedge clk);
    rst = 1'b0;
    send_byte(8'h11);
    send_byte(8'h22);
    send_byte(8'h33);
    send_byte(8'h44);
    rx_valid = 1'b0;
    wait (tx_request);
    @(negedge clk);
    tx_ack = 1'b1;
    @(negedge clk);
    tx_ack = 1'b0;
    wait (echo_count == 4);
    wait (sample_count == 3);
    #20;
    if (tx_length !== 16'd4) $fatal(1, "echo length mismatch");
    if ((phy_id1 !== 16'h001c) || (phy_id2 !== 16'hc915) ||
        (phy_status !== 16'hac00)) begin
        $display("MDIO values: %04x %04x %04x", phy_id1, phy_id2, phy_status);
        $fatal(1, "MDIO register mismatch");
    end
    $display("PASS: MAIN5A control plane");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "timeout");
end
endmodule
