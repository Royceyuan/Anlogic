`timescale 1 ns / 100 fs

// PLL parameters copied from the routed official_lab6_td621 reference.
// C2 phase 3 is the reference's 180-degree SDRAM write clock.
module sdram_pll_official_125m_exact (
    input  wire refclk,
    input  wire reset,
    output wire clk0_out,
    output wire clk1_out,
    output wire clk2_out
);

wire clk0_buf;

EG_LOGIC_BUFG bufg_feedback (
    .i(clk0_buf),
    .o(clk0_out)
);

EG_PHY_PLL #(
    .DPHASE_SOURCE("DISABLE"),
    .DYNCFG("DISABLE"),
    .FIN("50.000000"),
    .FEEDBK_MODE("NORMAL"),
    .FEEDBK_PATH("CLKC0_EXT"),
    .STDBY_ENABLE("DISABLE"),
    .PLLRST_ENA("ENABLE"),
    .SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4),
    .ICP_CURRENT(29),
    .KVCO(4),
    .LPF_CAPACITOR(1),
    .LPF_RESISTOR(2),
    .REFCLK_DIV(1),
    .FBCLK_DIV(2),
    .CLKC0_ENABLE("ENABLE"),
    .CLKC0_DIV(10),
    .CLKC0_CPHASE(9),
    .CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"),
    .CLKC1_DIV(8),
    .CLKC1_CPHASE(7),
    .CLKC1_FPHASE(0),
    .CLKC2_ENABLE("ENABLE"),
    .CLKC2_DIV(8),
    .CLKC2_CPHASE(3),
    .CLKC2_FPHASE(0)
) pll_inst (
    .refclk(refclk),
    .reset(reset),
    .stdby(1'b0),
    .extlock(open),
    .load_reg(1'b0),
    .psclk(1'b0),
    .psdown(1'b0),
    .psstep(1'b0),
    .psclksel(3'b000),
    .psdone(open),
    .dclk(1'b0),
    .dcs(1'b0),
    .dwe(1'b0),
    .di(8'b0),
    .daddr(6'b0),
    .do({open, open, open, open, open, open, open, open}),
    .fbclk(clk0_out),
    .clkc({open, open, clk2_out, clk1_out, clk0_buf})
);

endmodule
