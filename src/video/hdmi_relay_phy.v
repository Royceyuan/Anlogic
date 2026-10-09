`timescale 1ns / 1ps
`default_nettype none

// Shared IOL latency on all four lanes preserves video, audio and TMDS clock.
// Chronological nibble order is q0,q1,q2,q3. No payload reconstruction.
module hdmi_relay_phy (
    input wire pclk, sclk, sampler_rst, transmitter_rst,
    input wire [3:0] serial_in,
    output wire [15:0] nibbles,
    output wire [3:0] serial_out
);
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : g_lane
    EG_LOGIC_IDDRx2 u_sample (
        .q0(nibbles[lane*4]), .q1(nibbles[lane*4+1]),
        .q2(nibbles[lane*4+2]), .q3(nibbles[lane*4+3]),
        .pclk(pclk), .sclk(sclk), .d(serial_in[lane]), .rst(sampler_rst)
    );
    EG_LOGIC_ODDRx2 u_transmit (
        .q(serial_out[lane]), .pclk(pclk), .sclk(sclk), .rst(transmitter_rst),
        .d0(nibbles[lane*4]), .d1(nibbles[lane*4+1]),
        .d2(nibbles[lane*4+2]), .d3(nibbles[lane*4+3])
    );
end endgenerate
endmodule
`default_nettype wire
