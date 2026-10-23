`timescale 1 ns / 100 fs

// 25 MHz SDRAM clock set. The official burst/FIFO path is retained, while
// the lower clock rate gives the SDRAM hard macro a robust timing margin.
module system_clock_pll (
    refclk,
    reset,
    clk0_out,
    clk1_out,
    clk2_out,
    locked
);

input refclk;
input reset;
output clk0_out;
output clk1_out;
output clk2_out;
output locked;

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
    .LPF_RESISTOR(4),
    .REFCLK_DIV(1),
    .FBCLK_DIV(20),
    .CLKC0_ENABLE("ENABLE"),
    .CLKC0_DIV(40),
    .CLKC0_CPHASE(39),
    .CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"),
    .CLKC1_DIV(40),
    .CLKC1_CPHASE(39),
    .CLKC1_FPHASE(0),
    .CLKC2_ENABLE("ENABLE"),
    .CLKC2_DIV(40),
    .CLKC2_CPHASE(10),
    .CLKC2_FPHASE(0)
) pll_inst (
    .refclk(refclk),
    .reset(reset),
    .stdby(1'b0),
    .extlock(locked),
    .load_reg(1'b0),
    .psclk(1'b0),
    .psdown(1'b0),
    .psstep(1'b0),
    .psclksel(3'b000),
    .psdone(open),
    .dclk(1'b0),
    .dcs(1'b0),
    .dwe(1'b0),
    .di(8'b00000000),
    .daddr(6'b000000),
    .do({open, open, open, open, open, open, open, open}),
    .fbclk(1'b0),
    .clkc({open, open, clk2_out, clk1_out, clk0_buf})
);

endmodule
