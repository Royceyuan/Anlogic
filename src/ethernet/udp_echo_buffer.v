`timescale 1ns / 1ps
`default_nettype none

module udp_echo_buffer (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    input  wire [15:0] rx_length,
    input  wire        tx_ready,
    input  wire        tx_ack,
    output reg         tx_request,
    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    output reg  [15:0] tx_length
);

localparam WAIT_RX  = 2'd0;
localparam WAIT_ACK = 2'd1;
localparam SEND     = 2'd2;

reg [1:0] state;
reg [11:0] write_pointer;
reg [11:0] read_pointer;
reg [15:0] packet_length;
reg [15:0] sent_count;
reg rx_valid_d;

wire [11:0] ram_read_address = (state == SEND) ? read_pointer + 12'd1 : 12'd0;
wire [7:0] ram_read_data;

`ifdef SIM
reg [7:0] memory [0:4095];
always @(posedge clk) begin
    if (rx_valid)
        memory[write_pointer] <= rx_data;
end
assign ram_read_data = memory[ram_read_address];
`else
wire [7:0] unused_a;
EG_LOGIC_BRAM #(
    .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
    .ADDR_WIDTH_A(12), .ADDR_WIDTH_B(12),
    .DATA_DEPTH_A(4096), .DATA_DEPTH_B(4096),
    .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
    .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
    .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
    .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
    .IMPLEMENT("32K")
) u_packet_ram (
    .doa(unused_a), .dob(ram_read_data), .dia(rx_data), .dib(8'd0),
    .cea(rx_valid), .ocea(1'b0), .clka(clk), .wea(rx_valid), .rsta(1'b0),
    .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
    .bea(1'b1), .beb(1'b1), .addra(write_pointer), .addrb(ram_read_address)
);
`endif

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= WAIT_RX;
        write_pointer <= 12'd0;
        read_pointer <= 12'd0;
        packet_length <= 16'd0;
        sent_count <= 16'd0;
        rx_valid_d <= 1'b0;
        tx_request <= 1'b0;
        tx_data <= 8'd0;
        tx_valid <= 1'b0;
        tx_length <= 16'd0;
    end else begin
        rx_valid_d <= rx_valid;
        if (rx_valid) begin
            write_pointer <= write_pointer + 12'd1;
            packet_length <= (rx_length > 16'd4096) ? 16'd4096 : rx_length;
        end

        case (state)
            WAIT_RX: begin
                tx_valid <= 1'b0;
                if (rx_valid_d && !rx_valid && (packet_length != 16'd0) && tx_ready) begin
                    read_pointer <= 12'd0;
                    sent_count <= 16'd0;
                    tx_length <= packet_length;
                    tx_data <= ram_read_data;
                    tx_request <= 1'b1;
                    state <= WAIT_ACK;
                end
            end
            WAIT_ACK: begin
                if (tx_ack) begin
                    tx_request <= 1'b0;
                    tx_valid <= 1'b1;
                    state <= SEND;
                end
            end
            SEND: begin
                if (sent_count == packet_length - 16'd1) begin
                    tx_valid <= 1'b0;
                    write_pointer <= 12'd0;
                    packet_length <= 16'd0;
                    state <= WAIT_RX;
                end else begin
                    tx_data <= ram_read_data;
                    read_pointer <= read_pointer + 12'd1;
                    sent_count <= sent_count + 16'd1;
                end
            end
            default: state <= WAIT_RX;
        endcase
    end
end

endmodule

`default_nettype wire
