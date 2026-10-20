`timescale 1ns/1ps
`default_nettype none
// Read-only first milestone for offline video: verify native four-bit throughput.
// This diagnostic top does not instantiate the museum display or Ethernet logic.
module top_secondary_tf_read_probe(
    input wire clk_50m,key_reset_n,
    output wire sd_clk,
    inout wire sd_cmd,
    inout wire [3:0] sd_dat,
    output wire [3:0] led,
    output reg [7:0] seg_data,seg_sel
);
wire clk,feedback_raw,feedback,clock_raw,locked;
wire open_clock4,open_clock3,open_clock2;
EG_LOGIC_BUFG u_clock(.i(clock_raw),.o(clk));
EG_LOGIC_BUFG u_feedback(.i(feedback_raw),.o(feedback));
EG_PHY_PLL #(
    .FIN("50.000000"),.FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC1_EXT"),
    .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.STDBY_ENABLE("DISABLE"),
    .PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4),.ICP_CURRENT(13),.KVCO(4),.LPF_CAPACITOR(1),.LPF_RESISTOR(4),
    .REFCLK_DIV(1),.FBCLK_DIV(1),
    .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(10),.CLKC0_CPHASE(9),.CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(20),.CLKC1_CPHASE(19),.CLKC1_FPHASE(0)
) u_pll(
    .refclk(clk_50m),.reset(1'b0),.stdby(1'b0),.extlock(locked),
    .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b000),.psdone(),
    .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'b0),.daddr(6'b0),.do(),.fbclk(feedback),
    .clkc({open_clock4,open_clock3,open_clock2,feedback_raw,clock_raw}));
wire async_rst_n=locked&&key_reset_n;
reg [2:0] release_reset=0;
always @(posedge clk or negedge async_rst_n)
    if(!async_rst_n) release_reset<=0;else release_reset<={release_reset[1:0],1'b1};
wire rst_n=release_reset[2];
assign sd_dat=4'bzzzz;
wire initialized,high_speed,busy,done,valid;
wire [7:0] data,error,stage;
wire [31:0] blocks;
reg start,started,finished;
reg [16:0] ms_cycles;
reg [23:0] elapsed_ms,checksum;
reg [27:0] heartbeat;
sd_native_read u_reader(.clk(clk),.rst_n(rst_n),.read_start(start),
    .read_lba(32'd0),.read_blocks(32'd32768),
    .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat),
    .initialized(initialized),.high_speed(high_speed),.busy(busy),.done(done),
    .data_valid(valid),.data(data),.verified_blocks(blocks),.error(error),.stage(stage));
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        start<=0;started<=0;finished<=0;ms_cycles<=0;elapsed_ms<=0;checksum<=0;heartbeat<=0;
    end else begin
        heartbeat<=heartbeat+1'b1;start<=0;
        if(initialized&&!started) begin start<=1;started<=1;end
        if(started&&!finished&&error==0) begin
            if(ms_cycles==99999) begin ms_cycles<=0;elapsed_ms<=elapsed_ms+1'b1;end
            else ms_cycles<=ms_cycles+1'b1;
        end
        if(valid) checksum<=checksum+data;
        if(done) finished<=1;
    end
end
assign led={error!=0,finished,initialized,heartbeat[25]};
wire [31:0] displayed=error!=0?{8'hf0,stage,8'h00,error}:
    !initialized?{24'ha00000,stage}:!finished?{8'hb0,blocks[23:0]}:
    heartbeat[27:26]==0?{8'hc0,elapsed_ms}:
    heartbeat[27:26]==1?{8'hd0,blocks[23:0]}:
    heartbeat[27:26]==2?{8'he0,checksum}:{24'ha00000,7'd0,high_speed};
function [7:0] segments;
    input [3:0] digit;
    begin case(digit)
        0:segments=8'hc0;1:segments=8'hf9;2:segments=8'ha4;3:segments=8'hb0;
        4:segments=8'h99;5:segments=8'h92;6:segments=8'h82;7:segments=8'hf8;
        8:segments=8'h80;9:segments=8'h90;10:segments=8'h88;11:segments=8'h83;
        12:segments=8'hc6;13:segments=8'ha1;14:segments=8'h86;default:segments=8'h8e;
    endcase end
endfunction
always @* begin
    seg_sel=~(8'b1<<heartbeat[16:14]);
    seg_data=segments((displayed>>(heartbeat[16:14]*4))&4'hf);
end
endmodule
`default_nettype wire
