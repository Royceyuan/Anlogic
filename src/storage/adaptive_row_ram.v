`timescale 1ns / 1ps
`default_nettype none

// One-port write, asynchronous read row store. TD maps the primitive to
// EG4 block RAM; the SIM model below keeps the loader testbench portable.
`ifdef SIM
module EG_LOGIC_BRAM #(
    parameter integer DATA_WIDTH_A = 16,
    parameter integer DATA_WIDTH_B = 16,
    parameter integer ADDR_WIDTH_A = 11,
    parameter integer ADDR_WIDTH_B = 11,
    parameter integer DATA_DEPTH_A = 2048,
    parameter integer DATA_DEPTH_B = 2048,
    parameter integer BYTE_ENABLE = 0,
    parameter integer BYTE_A = 1,
    parameter integer BYTE_B = 1,
    parameter MODE = "DP",
    parameter REGMODE_A = "NOREG",
    parameter REGMODE_B = "NOREG",
    parameter WRITEMODE_A = "NORMAL",
    parameter WRITEMODE_B = "NORMAL",
    parameter RESETMODE = "SYNC",
    parameter DEBUGGABLE = "NO",
    parameter PACKABLE = "NO",
    parameter FORCE_KEEP = "OFF",
    parameter INIT_FILE = "NONE",
    parameter FILL_ALL = "NONE",
    parameter IMPLEMENT = "9K"
) (
    output reg [DATA_WIDTH_A-1:0] doa,
    output reg [DATA_WIDTH_B-1:0] dob,
    input wire [DATA_WIDTH_A-1:0] dia,
    input wire [DATA_WIDTH_B-1:0] dib,
    input wire cea, ocea, clka, wea, rsta,
    input wire ceb, oceb, clkb, web, rstb,
    input wire bea, beb,
    input wire [ADDR_WIDTH_A-1:0] addra,
    input wire [ADDR_WIDTH_B-1:0] addrb
);
    reg [DATA_WIDTH_A-1:0] memory [0:DATA_DEPTH_A-1];
    always @(posedge clka)
        if (cea && wea)
            memory[addra] <= dia;
    always @(*) begin
        doa = {DATA_WIDTH_A{1'b0}};
        dob = memory[addrb];
    end
endmodule
`endif

module adaptive_row_ram #(
    parameter integer ADDR_WIDTH = 11,
    parameter integer DATA_DEPTH = 1280,
    parameter IMPLEMENT = "9K"
) (
    input wire                  clk,
    input wire                  wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [15:0]           wr_data,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [15:0]          rd_data
);

wire [15:0] unused_a;

EG_LOGIC_BRAM #(
    .DATA_WIDTH_A(16), .DATA_WIDTH_B(16),
    .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
    .DATA_DEPTH_A(2048), .DATA_DEPTH_B(2048),
    .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
    .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
    .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
    .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
    .IMPLEMENT(IMPLEMENT)
) u_row_ram (
    .doa(unused_a), .dob(rd_data), .dia(wr_data), .dib(16'd0),
    .cea(wr_en), .ocea(1'b0), .clka(clk), .wea(wr_en), .rsta(1'b0),
    .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
    .bea(1'b1), .beb(1'b1), .addra(wr_addr), .addrb(rd_addr)
);

endmodule

`default_nettype wire
