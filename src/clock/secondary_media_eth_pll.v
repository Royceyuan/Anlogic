`timescale 1ns / 100fs
`default_nettype none

// One 1GHz VCO supplies the original SDRAM clocks and fixed-gigabit TX clocks.
// C1/C2 retain the exact divide/phase settings of the validated memory PLL.
// C0/C3 retain the divide/phase relationship of the original Ethernet TX PLL.
module secondary_media_eth_pll (
    input wire refclk, reset,
    output wire mem_clk, mem_clk_sft,
    output wire eth_clk, eth_clk_90,
    output wire locked
);
wire open_clock, mem_clock_raw, eth_clock_raw;
EG_LOGIC_BUFG u_memory_clock (.i(mem_clock_raw), .o(mem_clk));
EG_LOGIC_BUFG u_ethernet_clock (.i(eth_clock_raw), .o(eth_clk));
EG_PHY_PLL #(
    .FIN("50.000000"), .FEEDBK_MODE("NORMAL"), .FEEDBK_PATH("CLKC1_EXT"),
    .DPHASE_SOURCE("DISABLE"), .DYNCFG("DISABLE"),
    .STDBY_ENABLE("DISABLE"), .PLLRST_ENA("ENABLE"), .SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4), .ICP_CURRENT(13), .KVCO(4),
    .LPF_CAPACITOR(1), .LPF_RESISTOR(4), .REFCLK_DIV(1), .FBCLK_DIV(1),
    .CLKC0_ENABLE("ENABLE"), .CLKC0_DIV(8), .CLKC0_CPHASE(7), .CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"), .CLKC1_DIV(20), .CLKC1_CPHASE(19), .CLKC1_FPHASE(0),
    .CLKC2_ENABLE("ENABLE"), .CLKC2_DIV(20), .CLKC2_CPHASE(7), .CLKC2_FPHASE(0),
    .CLKC3_ENABLE("ENABLE"), .CLKC3_DIV(8), .CLKC3_CPHASE(1), .CLKC3_FPHASE(0)
) pll_inst (
    .refclk(refclk), .reset(reset), .stdby(1'b0), .extlock(locked),
    .load_reg(5'b0), .psclk(1'b0), .psdown(1'b0), .psstep(1'b0),
    .psclksel(3'b000), .psdone(), .dclk(1'b0), .dcs(1'b0), .dwe(1'b0),
    .di(8'b0), .daddr(6'b0), .do(), .fbclk(mem_clk),
    .clkc({open_clock, eth_clk_90, mem_clk_sft, mem_clock_raw, eth_clock_raw})
);
endmodule
`default_nettype wire
