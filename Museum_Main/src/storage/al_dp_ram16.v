`timescale 1ns / 1ps
`default_nettype none

// 16-bit simple-dual-port RAM: synchronous write, asynchronous read.
// The stable BIN path uses 512 entries, exactly one SD sector pair buffer.
module al_dp_ram16 #(
    parameter integer ADDR_WIDTH = 9,
    parameter integer DEPTH      = 512,
    parameter IMPLEMENT = "9K"
)(
    input  wire                  clk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [15:0]            wr_data,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [15:0]            rd_data
);

`ifdef SIM
    reg [15:0] memory [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en)
            memory[wr_addr] <= wr_data;
    end

    assign rd_data = memory[rd_addr];
`else
    wire [15:0] unused_a;

    EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(16), .DATA_WIDTH_B(16),
        .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
        .DATA_DEPTH_A(DEPTH), .DATA_DEPTH_B(DEPTH),
        .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
        .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
        .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
        .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
        .IMPLEMENT(IMPLEMENT)
    ) u_ram (
        .doa(unused_a), .dob(rd_data), .dia(wr_data), .dib(16'd0),
        .cea(wr_en), .ocea(1'b0), .clka(clk), .wea(wr_en), .rsta(1'b0),
        .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
        .bea(1'b1), .beb(1'b1), .addra(wr_addr), .addrb(rd_addr)
    );
`endif

endmodule

`default_nettype wire
