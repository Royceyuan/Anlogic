`timescale 1ns / 1ps
`default_nettype none

// Shared IOL latency on all four lanes preserves video, audio and TMDS clock.
// Chronological nibble order is q0,q1,q2,q3. No payload reconstruction.
module hdmi_relay_phy #(parameter integer EXTERNAL_TRANSMITTER=0) (
    input wire pclk, sclk, sampler_rst, transmitter_rst,
    input wire [3:0] serial_in,
    output wire [15:0] nibbles,
    output wire [3:0] serial_out,
    output wire [7:0] parallel_pairs
);
reg capture_toggle,serial_toggle;
always @(posedge pclk or posedge sampler_rst)
    if(sampler_rst) capture_toggle<=0;
    else capture_toggle<=!capture_toggle;
always @(negedge sclk) serial_toggle<=capture_toggle;
wire first_pair=capture_toggle!=serial_toggle;
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : g_lane
    EG_LOGIC_IDDRx2 u_sample (
        .q0(nibbles[lane*4]), .q1(nibbles[lane*4+1]),
        .q2(nibbles[lane*4+2]), .q3(nibbles[lane*4+3]),
        .pclk(pclk), .sclk(sclk), .d(serial_in[lane]), .rst(sampler_rst)
    );
    // Reuse the board-passed transmitter's single-clock output primitive.
    // pclk leads sclk by half a bit. A new captured word selects its first
    // pair; the next falling sclk selects its second. Do not use clock as data.
    // The common toggle keeps all lanes, including clock, in the same phase.
    // Register away from the IOL's rising edge instead of a two-clock TX IOL.
    reg [1:0] transmit_pair,output_pair;
    // Only the output IOL needs reset. Qualification leaves both pair stages
    // ample time to fill; resetting them adds a short half-cycle recovery net.
    always @(negedge sclk)
        transmit_pair<=first_pair ? nibbles[lane*4+:2] : nibbles[lane*4+2+:2];
    // Full-cycle path into the output IOL, as in the existing HDMI transmitter.
    always @(posedge sclk) output_pair<=transmit_pair;
    assign parallel_pairs[lane*2+:2]=output_pair;
    if (!EXTERNAL_TRANSMITTER) begin : g_output
    EG_LOGIC_ODDR u_transmit (
        .q(serial_out[lane]), .clk(sclk), .rst(transmitter_rst),
        .d0(output_pair[0]), .d1(output_pair[1])
    );
    end else begin : g_parallel
        assign serial_out[lane]=1'b0;
    end
end endgenerate
endmodule
`default_nettype wire
