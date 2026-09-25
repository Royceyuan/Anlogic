`timescale 1 ns / 100 fs

// Native 720p candidate: 50 MHz SDRAM command clock and a 144-degree
// shifted SDRAM clock. C2 is explicitly enabled; the earlier PLL source
// left C2 disabled and must not be used for this build.
module sys_pll (
    input wire refclk, input wire reset,
    output wire clk0_out, output wire clk1_out, output wire clk2_out
);
wire clk0_buf;
wire open;
EG_LOGIC_BUFG bufg_feedback (.i(clk0_buf), .o(clk0_out));
EG_PHY_PLL #(
    .DPHASE_SOURCE("DISABLE"), .DYNCFG("DISABLE"), .FIN("50.000000"),
    .FEEDBK_MODE("NOCOMP"), .FEEDBK_PATH("VCO_PHASE_0"),
    .STDBY_ENABLE("DISABLE"), .PLLRST_ENA("ENABLE"), .SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4), .ICP_CURRENT(13), .KVCO(4), .LPF_CAPACITOR(1), .LPF_RESISTOR(4),
    .REFCLK_DIV(1), .FBCLK_DIV(20),
    .CLKC0_ENABLE("ENABLE"), .CLKC0_DIV(20), .CLKC0_CPHASE(19), .CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"), .CLKC1_DIV(20), .CLKC1_CPHASE(19), .CLKC1_FPHASE(0),
    .CLKC2_ENABLE("ENABLE"), .CLKC2_DIV(20), .CLKC2_CPHASE(7), .CLKC2_FPHASE(0)
) pll_inst (
    .refclk(refclk), .reset(reset), .stdby(1'b0), .extlock(open),
    .load_reg(1'b0), .psclk(1'b0), .psdown(1'b0), .psstep(1'b0),
    .psclksel(3'b000), .psdone(open), .dclk(1'b0), .dcs(1'b0), .dwe(1'b0),
    .di(8'b0), .daddr(6'b0), .do({open,open,open,open,open,open,open,open}),
    .fbclk(1'b0), .clkc({open,open,clk2_out,clk1_out,clk0_buf})
);
endmodule
