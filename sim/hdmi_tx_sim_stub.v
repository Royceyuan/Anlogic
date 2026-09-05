`timescale 1ns / 1ps
`default_nettype none

// The HDMI encoder is a vendor/VHDL implementation and is not needed by the
// top-level control smoke test. Keep the ports identical so the rest of top
// is elaborated and exercised without modeling TMDS serialization.
module hdmi_tx #(
    parameter FAMILY = "EG4"
)(
    input  wire        PXLCLK_I,
    input  wire        PXLCLK_5X_I,
    input  wire        RST_N,
    input  wire        VGA_HS,
    input  wire        VGA_VS,
    input  wire        VGA_DE,
    input  wire [23:0] VGA_RGB,
    output wire        HDMI_CLK_P,
    output wire        HDMI_D2_P,
    output wire        HDMI_D1_P,
    output wire        HDMI_D0_P
);

assign HDMI_CLK_P = 1'b0;
assign HDMI_D2_P  = 1'b0;
assign HDMI_D1_P  = 1'b0;
assign HDMI_D0_P  = 1'b0;

endmodule

`default_nettype wire
