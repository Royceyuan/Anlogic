`timescale 1ns / 1ps
`default_nettype none

// 32-bit simple-dual-port RAM used by the output line buffers.
module al_dp_ram32 #(
    parameter integer ADDR_WIDTH = 9,
    parameter integer DEPTH      = 512,
    parameter integer REGISTER_READ = 0,
    // EG_LOGIC_BRAM's NOREG output still follows a synchronous array read.
    // Keep the legacy asynchronous simulation as the default so old
    // candidates are unchanged; new hardware-matched paths enable this.
    parameter integer NOREG_SYNC_READ = 0
) (
    input  wire                  clk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [31:0]           wr_data,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [31:0]           rd_data
);

`ifdef SIM
    reg [31:0] memory [0:DEPTH-1];
    reg [31:0] rd_array_q;
    reg [31:0] rd_data_q;

    always @(posedge clk) begin
        if (wr_en)
            memory[wr_addr] <= wr_data;
        if (NOREG_SYNC_READ)
            rd_array_q <= memory[rd_addr];
        if (REGISTER_READ)
            rd_data_q <= NOREG_SYNC_READ ? rd_array_q : memory[rd_addr];
    end

    assign rd_data = REGISTER_READ ? rd_data_q :
                     (NOREG_SYNC_READ ? rd_array_q : memory[rd_addr]);
`else
    wire [31:0] unused_a;

    EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(32), .DATA_WIDTH_B(32),
        .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
        .DATA_DEPTH_A(DEPTH), .DATA_DEPTH_B(DEPTH),
        .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
        .REGMODE_A("NOREG"),
        .REGMODE_B(REGISTER_READ ? "OUTREG" : "NOREG"),
        .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
        .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
        .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
        .IMPLEMENT("9K")
    ) u_ram (
        .doa(unused_a), .dob(rd_data), .dia(wr_data), .dib(32'd0),
        .cea(wr_en), .ocea(1'b0), .clka(clk), .wea(wr_en), .rsta(1'b0),
        .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
        .bea(1'b1), .beb(1'b1), .addra(wr_addr), .addrb(rd_addr)
    );
`endif

endmodule

`default_nettype wire
