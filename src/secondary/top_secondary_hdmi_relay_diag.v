`timescale 1ns / 1ps
`default_nettype none

// Independent board diagnostic. Does not include TF, SDRAM or Ethernet.
module top_secondary_hdmi_relay_diag #(
    parameter integer HPD_LOW_CYCLES=10000000
)(
    input wire clk_50m,
    input wire hdmi_b_clk_p,hdmi_b_d0_p,hdmi_b_d1_p,hdmi_b_d2_p,
    input wire hdmi_b_scl,
    inout wire hdmi_b_sda,
    output wire hdmi_b_hpd,
    input wire hdmi_a_hpd,
    output wire hdmi1_clk_p,hdmi1_d0_p,hdmi1_d1_p,hdmi1_d2_p,
    output wire [3:0] led,
    output wire [7:0] seg_data,seg_sel
);
reg [15:0] startup=0;
always @(posedge clk_50m) if(startup!=16'hffff) startup<=startup+1'b1;
wire rst_n=&startup;
reg [26:0] heartbeat;
reg [1:0] sink_ff;
always @(posedge clk_50m) begin
    if(!rst_n) begin heartbeat<=0; sink_ff<=0; end
    else begin heartbeat<=heartbeat+1'b1; sink_ff<={sink_ff[0],hdmi_a_hpd}; end
end
wire sda_low;
reg [23:0] hpd_cycles;
always @(posedge clk_50m) begin
    if(!rst_n) hpd_cycles<=0;
    else if(hpd_cycles!=HPD_LOW_CYCLES-1) hpd_cycles<=hpd_cycles+1'b1;
end
wire edid_ready=rst_n && hpd_cycles==HPD_LOW_CYCLES-1;
wire edid_request_seen,edid_read_seen;
wire [7:0] ddc_bus_status;
wire [3:0] ddc_parser_state;
assign hdmi_b_sda=sda_low ? 1'b0 : 1'bz;
// The FPGA owns the upstream EDID. Keep it available independently of the
// output monitor; a 200 ms low interval requests fresh enumeration after JTAG.
assign hdmi_b_hpd=edid_ready;
hdmi_edid_720p u_edid(.clk(clk_50m),.rst_n(rst_n),.enable(rst_n),
    .scl(hdmi_b_scl),.sda(hdmi_b_sda),.sda_low(sda_low),
    .request_seen(edid_request_seen),.read_seen(edid_read_seen),
    .bus_status(ddc_bus_status),.parser_state(ddc_parser_state));
wire pclk,sclk,pixel_clk,pll_locked,phase_done,clock_valid;
wire [19:0] measured_edges;
reg clock_activity_seen;
always @(posedge clk_50m)
    if(!rst_n) clock_activity_seen<=0;
    else if(measured_edges!=0) clock_activity_seen<=1;
reg phase_step;
reg [5:0] settle_cycles;
hdmi_relay_clock u_clock(.clk_50m(clk_50m),.rst_n(rst_n),.source_clk(hdmi_b_clk_p),
    .phase_step(phase_step),.phase_select(settle_cycles[5]),.pclk(pclk),.sclk(sclk),.pixel_clk(pixel_clk),
    .pll_locked(pll_locked),.phase_done(phase_done),.clock_valid(clock_valid),
    .measured_edges(measured_edges));
wire format_ok,lanes_locked,frame_toggle;
wire [11:0] bit_offsets;
reg [1:0] format_ff,lock_ff,pll_ff;
reg [23:0] seek_cycles;
reg [3:0] phase_index;
reg phase_busy;
always @(posedge clk_50m) begin
    if(!rst_n) begin
        format_ff<=0;lock_ff<=0;pll_ff<=0;seek_cycles<=0;
        settle_cycles<=0;phase_index<=0;phase_step<=0;phase_busy<=0;
    end else begin
        format_ff<={format_ff[0],format_ok};lock_ff<={lock_ff[0],lanes_locked};
        pll_ff<={pll_ff[0],pll_locked};
        if(!clock_valid||!pll_ff[1]) begin
            seek_cycles<=0;settle_cycles<=0;phase_step<=0;phase_busy<=0;phase_index<=0;
        end else if(phase_busy) begin
            if(settle_cycles<4 || (settle_cycles>=32 && settle_cycles<36)) begin phase_step<=1;settle_cycles<=settle_cycles+1'b1; end
            else begin
                phase_step<=0;
                // Fixed bounded settle exceeds the documented eight-PSCLK step.
                // Never leave the sampler in reset waiting for a missed pulse.
                if(settle_cycles==63) begin phase_busy<=0;seek_cycles<=0; end
                else if(settle_cycles!=63) settle_cycles<=settle_cycles+1'b1;
            end
        end else if(format_ff[1]) seek_cycles<=0;
        else if(seek_cycles==9999999) begin
            phase_busy<=1;settle_cycles<=0;phase_index<=phase_index+1'b1;
        end else seek_cycles<=seek_cycles+1'b1;
    end
end
wire rx_reset_n;
reset_sync u_sample_reset(.clk(pclk),.arst_n(rst_n&&clock_valid&&pll_locked&&!phase_busy),.srst_n(rx_reset_n));
wire [15:0] nibbles;
wire [3:0] outgoing;
wire transmit_allowed=rx_reset_n&&format_ok&&sink_ff[1];
reg [1:0] tx_reset=2'b11;
always @(posedge sclk or negedge transmit_allowed)
    if(!transmit_allowed) tx_reset<=2'b11;
    else tx_reset<={tx_reset[0],1'b0};
wire tx_reset_n=!tx_reset[1];
hdmi_relay_phy u_phy(.pclk(pclk),.sclk(sclk),.sampler_rst(!rx_reset_n),
    .transmitter_rst(tx_reset[1]),
    .serial_in({hdmi_b_clk_p,hdmi_b_d2_p,hdmi_b_d1_p,hdmi_b_d0_p}),
    .nibbles(nibbles),.serial_out(outgoing));
hdmi_tmds_monitor u_monitor(.clk(pclk),.rst_n(rx_reset_n),.nibbles(nibbles[11:0]),
    .lanes_locked(lanes_locked),.format_ok(format_ok),.frame_toggle(frame_toggle),.bit_offsets(bit_offsets));
assign {hdmi1_clk_p,hdmi1_d2_p,hdmi1_d1_p,hdmi1_d0_p}=outgoing;
assign led={format_ff[1],pll_ff[1],clock_valid,heartbeat[24]};
wire [15:0] diagnostic_value=heartbeat[25] ? measured_edges[19:4] :
    heartbeat[26] ? {4'hb,ddc_bus_status[7:1],clock_activity_seen,ddc_parser_state} :
    {4'ha,edid_ready,sink_ff[1],edid_read_seen,edid_request_seen,
     clock_valid,pll_ff[1],lock_ff[1],format_ff[1],phase_index};
seg_hex_display u_seg(.clk(clk_50m),.rst_n(rst_n),
    // A status, clock count, B bus probe, clock count; 0.67 s per page.
    .value(diagnostic_value),
    .seg_data(seg_data),.seg_sel(seg_sel));
endmodule
`default_nettype wire
