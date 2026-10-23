`timescale 1ns / 1ps
`default_nettype none
// Reuse the main board's vendor transmitter, including its HDMI preambles,
// guard bands and InfoFrames. Only the local source changes; PC AV stays raw.
module secondary_hdmi_packet_symbols #(parameter integer AUDIO_ENABLE=0)(
    input wire clk,rst_n,vs,de,
    input wire [23:0] rgb,
    input wire audio_valid,acr_valid,
    input wire [31:0] audio_data,
    input wire [19:0] acr_cts,acr_n,
    output wire [39:0] symbols,
    output wire locked
);
reg vs_d=0,de_d=0,frame_arm=1;
reg [10:0] x_count=0;
reg axis_user=0,axis_valid=0,axis_last=0;
reg [23:0] axis_data=0;
reg [23:0] rgb_d=0;
reg last_d=0;
wire axis_ready;
wire frame_start=frame_arm&&de&&!de_d;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vs_d<=0;de_d<=0;frame_arm<=1;x_count<=0;
        axis_user<=0;axis_valid<=0;axis_last<=0;axis_data<=0;rgb_d<=0;last_d<=0;
    end else begin
        vs_d<=vs;de_d<=de;rgb_d<=rgb;last_d<=0;
        // Re-arm one cycle before raster data. During initial acquisition the
        // receiver needs a valid SOF beat; once locked, do not duplicate that
        // beat into the FIFO. The first real pixel always follows unchanged.
        axis_user<=frame_start;axis_valid<=de_d||(frame_start&&!locked);
        axis_last<=last_d;axis_data<=frame_start?rgb:rgb_d;
        if(vs_d!=vs) frame_arm<=1;
        if(de) begin
            if(!de_d) begin x_count<=0;if(frame_arm) frame_arm<=0;end
            else x_count<=x_count+1'b1;
            if(de_d&&x_count==1278) last_d<=1;
        end else x_count<=0;
    end
end
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE("EG"),.HTOTAL(1650),.HSA(40),.HFP(110),.HBP(220),.HACTIVE(1280),
    .VTOTAL(750),.VSA(5),.VFP(5),.VBP(20),.VACTIVE(720),
    .VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),.VIDEO_VIC(0),
    .AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(750)
) u_core(
    .I_pixel_clk(clk),.I_rst(!rst_n),.I_edid_read_trig(1'b0),
    .O_edid_read_valid(),.O_edid_read_data(),
    .I_axis_s_user(axis_user),.I_axis_s_valid(axis_valid),.I_axis_s_last(axis_last),
    .I_axis_s_data(axis_data),.O_axis_s_ready(axis_ready),
    .I_audio_valid(AUDIO_ENABLE?audio_valid:1'b0),
    .I_audio_left_data(AUDIO_ENABLE?{audio_data[15:0],8'd0}:24'd0),
    .I_audio_right_data(AUDIO_ENABLE?{audio_data[31:16],8'd0}:24'd0),
    .I_acr_valid(AUDIO_ENABLE?acr_valid:1'b0),.I_acr_cts(AUDIO_ENABLE?acr_cts:20'd0),
    .I_acr_n(AUDIO_ENABLE?acr_n:20'd6144),
    .O_video_locked(locked),.O_ddc_scl(),.IO_ddc_sda(),
    .O_ch0_tmds_data(symbols[9:0]),.O_ch1_tmds_data(symbols[19:10]),
    .O_ch2_tmds_data(symbols[29:20]),.O_clk_tmds_data(symbols[39:30])
);
endmodule
`default_nettype wire
