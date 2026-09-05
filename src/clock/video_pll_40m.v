`timescale 1 ns / 100 fs

// 800x600@60 uses a 40 MHz pixel clock and a 200 MHz 5x serializer clock.
// NOCOMP mode follows the official 25/40 MHz VGA PLL example: a 1000 MHz
// VCO is divided by 25 for the pixel clock and by 5 for the 5x clock.
module video_pll_40m (
    input  wire refclk,
    input  wire reset,
    output wire clk0_out,
    output wire clk1_out
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
    .FEEDBK_MODE("NOCOMP"),
    .FEEDBK_PATH("VCO_PHASE_0"),
    .STDBY_ENABLE("DISABLE"),
    .PLLRST_ENA("ENABLE"),
    .SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4),
    .ICP_CURRENT(13),
    .KVCO(4),
    .LPF_CAPACITOR(1),
    .LPF_RESISTOR(8),
    .REFCLK_DIV(1),
    .FBCLK_DIV(20),
    .CLKC0_ENABLE("ENABLE"),
    .CLKC0_DIV(25),
    .CLKC0_CPHASE(24),
    .CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"),
    .CLKC1_DIV(5),
    .CLKC1_CPHASE(4),
    .CLKC1_FPHASE(0)
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
    .clkc({open, open, open, clk1_out, clk0_buf})
);

endmodule
