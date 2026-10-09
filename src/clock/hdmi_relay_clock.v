`timescale 1ns / 100fs
`default_nettype none
module hdmi_relay_clock #(
    parameter integer CLOCKS_PER_MS=50000
) (
    input wire clk_50m, rst_n, source_clk, phase_step, phase_select,
    output wire sclk, pclk, pixel_clk, pll_locked, phase_done,
    output reg clock_valid,
    output reg [19:0] measured_edges
);
reg [23:0] source_count;
reg [23:0] source_gray;
wire [23:0] source_next=source_count+1'b1;
reg [23:0] gray_ff1,gray_ff2,last_count;
reg [15:0] window_cycles;
reg [1:0] good_windows;
function [23:0] from_gray;
input [23:0] gray;
integer i;
begin
    from_gray[23]=gray[23];
    for(i=22;i>=0;i=i-1) from_gray[i]=from_gray[i+1]^gray[i];
end endfunction
wire [23:0] count_now=from_gray(gray_ff2);
wire [23:0] count_delta=count_now-last_count;
always @(posedge source_clk or negedge rst_n)
    if(!rst_n) begin source_count<=0;source_gray<=0;end
    else begin source_count<=source_next;source_gray<=(source_next>>1)^source_next;end
always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin
        gray_ff1<=0; gray_ff2<=0; last_count<=0; window_cycles<=0;
        good_windows<=0; clock_valid<=0; measured_edges<=0;
    end else begin
        gray_ff1<=source_gray; gray_ff2<=gray_ff1;
        if(window_cycles==CLOCKS_PER_MS-1) begin
            window_cycles<=0; last_count<=count_now; measured_edges<=count_delta[19:0];
            if(count_delta>=CLOCKS_PER_MS*148/100 && count_delta<=CLOCKS_PER_MS*149/100) begin
                if(good_windows!=3) good_windows<=good_windows+1'b1;
                if(good_windows>=2) clock_valid<=1;
            end else begin good_windows<=0; clock_valid<=0; end
        end else window_cycles<=window_cycles+1'b1;
    end
end
wire [4:0] clocks;
EG_LOGIC_BUFG u_sclk(.i(clocks[0]),.o(sclk));
EG_LOGIC_BUFG u_pclk(.i(clocks[1]),.o(pclk));
EG_LOGIC_BUFG u_pixel(.i(clocks[2]),.o(pixel_clk));
EG_PHY_PLL #(
    .FIN("74.250000"),.FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC2_EXT"),
    .DPHASE_SOURCE("ENABLE"),.DYNCFG("DISABLE"),
    .STDBY_ENABLE("DISABLE"),.PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4),.ICP_CURRENT(13),.KVCO(4),.LPF_CAPACITOR(1),.LPF_RESISTOR(4),
    .REFCLK_DIV(1),.FBCLK_DIV(1),
    .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(2),.CLKC0_CPHASE(1),.CLKC0_FPHASE(4),
    .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(4),.CLKC1_CPHASE(3),.CLKC1_FPHASE(4),
    .CLKC2_ENABLE("ENABLE"),.CLKC2_DIV(10),.CLKC2_CPHASE(9),.CLKC2_FPHASE(4)
) u_rx_pll(
    .refclk(source_clk),.reset(!rst_n||!clock_valid),.stdby(1'b0),.extlock(pll_locked),
    .load_reg(1'b0),.psclk(clk_50m),.psdown(1'b0),.psstep(phase_step),
    // Shift the two IOL clocks separately; leave pixel feedback unchanged.
    .psclksel({2'b00,phase_select}),.psdone(phase_done),.dclk(1'b0),.dcs(1'b0),.dwe(1'b0),
    .di(8'b0),.daddr(6'b0),.do(),.fbclk(pixel_clk),.clkc(clocks)
);
endmodule
`default_nettype wire
