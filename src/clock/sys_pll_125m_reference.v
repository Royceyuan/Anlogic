`timescale 1 ns / 100 fs

// Compatibility name for the PLL recipe used by the shipped HX4S20 lab6
// reference.  sdram_pll_tuned contains the TD-translated 125 MHz/180-degree
// clock parameters; this wrapper preserves the active diagnostic port names.
module sys_pll (
    input  wire refclk,
    input  wire reset,
    output wire clk0_out,
    output wire clk1_out,
    output wire clk2_out
);

sdram_pll_official_125m_exact u_reference (
    .refclk   (refclk),
    .reset    (reset),
    .clk0_out (clk0_out),
    .clk1_out (clk1_out),
    .clk2_out (clk2_out)
);

endmodule
