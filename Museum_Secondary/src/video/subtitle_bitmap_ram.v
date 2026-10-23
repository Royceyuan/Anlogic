`timescale 1ns/1ps
`default_nettype none
// Extracted unchanged from the main-board subtitle RAM, without its UART logic.
module subtitle_bitmap_ram #(
    parameter integer ADDR_WIDTH=12,DEPTH=4096,REGISTER_READ=0
)(
    input wire wr_clk,wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [7:0] wr_data,
    input wire rd_clk,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [7:0] rd_data
);
`ifdef SIM
reg [7:0] memory[0:DEPTH-1];
reg [7:0] rd_array_q,rd_data_q;
always @(posedge wr_clk)if(wr_en)memory[wr_addr]<=wr_data;
always @(posedge rd_clk)begin
    rd_array_q<=memory[rd_addr];
    if(REGISTER_READ)rd_data_q<=rd_array_q;
end
assign rd_data=REGISTER_READ?rd_data_q:rd_array_q;
`else
wire [7:0] unused_a;
EG_LOGIC_BRAM #(
    .DATA_WIDTH_A(8),.DATA_WIDTH_B(8),.ADDR_WIDTH_A(ADDR_WIDTH),.ADDR_WIDTH_B(ADDR_WIDTH),
    .DATA_DEPTH_A(DEPTH),.DATA_DEPTH_B(DEPTH),.BYTE_ENABLE(0),.BYTE_A(1),.BYTE_B(1),
    .MODE("DP"),.REGMODE_A("NOREG"),.REGMODE_B(REGISTER_READ?"OUTREG":"NOREG"),
    .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),.RESETMODE("SYNC"),
    .DEBUGGABLE("NO"),.PACKABLE("NO"),.FORCE_KEEP("OFF"),.INIT_FILE("NONE"),
    .FILL_ALL("NONE"),.IMPLEMENT("32K")
) u_ram(.doa(unused_a),.dob(rd_data),.dia(wr_data),.dib(8'd0),
    .cea(wr_en),.ocea(1'b0),.clka(wr_clk),.wea(wr_en),.rsta(1'b0),
    .ceb(1'b1),.oceb(1'b1),.clkb(rd_clk),.web(1'b0),.rstb(1'b0),
    .bea(1'b1),.beb(1'b1),.addra(wr_addr),.addrb(rd_addr));
`endif
endmodule
`default_nettype wire
