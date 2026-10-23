`timescale 1ns/1ps
`default_nettype none
`ifndef TF_VIDEO_FPS
`define TF_VIDEO_FPS 30
`endif
`ifndef TF_VIDEO_HEIGHT
`define TF_VIDEO_HEIGHT 360
`endif
// Standalone offline-video acceptance top. Does not replace the museum top.
module top_secondary_tf_video #(parameter OFFLINE_LINK=0,AV_ENABLE=0)(
    input wire clk_50m,key_reset_n,key_pause_n,
    input wire offline_control_rst_n,
    input wire [40:0] offline_request,
    input wire [55:0] offline_status,
    output wire offline_muted_ack,
    output wire sd_clk,
    inout wire sd_cmd,
    inout wire [3:0] sd_dat,
    output wire [3:0] led,
    output reg [7:0] seg_data,seg_sel,
    output wire hdmi_b_clk_p,hdmi_b_d0_p,hdmi_b_d1_p,hdmi_b_d2_p
);
localparam integer VIDEO_FPS=`TF_VIDEO_FPS;
localparam integer VIDEO_HEIGHT=`TF_VIDEO_HEIGHT;
localparam integer FRAME_BYTES=640*VIDEO_HEIGHT*2;
localparam integer VIDEO_BASE=VIDEO_HEIGHT==480?0:1843200;
wire clk,mem_clk,mem_sft,core_raw,mem_raw,locked,video_locked;
wire open_c3,open_c4;
EG_LOGIC_BUFG u_core_clock(.i(core_raw),.o(clk));
EG_LOGIC_BUFG u_memory_clock(.i(mem_raw),.o(mem_clk));
// Keep the successful probe C0/C1 settings; add the board-proven SDRAM C2.
EG_PHY_PLL #(
    .FIN("50.000000"),.FEEDBK_MODE("NORMAL"),.FEEDBK_PATH("CLKC1_EXT"),
    .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.STDBY_ENABLE("DISABLE"),
    .PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4),.ICP_CURRENT(13),.KVCO(4),.LPF_CAPACITOR(1),.LPF_RESISTOR(4),
    .REFCLK_DIV(1),.FBCLK_DIV(1),
    .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(10),.CLKC0_CPHASE(9),.CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(20),.CLKC1_CPHASE(19),.CLKC1_FPHASE(0),
    .CLKC2_ENABLE("ENABLE"),.CLKC2_DIV(20),.CLKC2_CPHASE(7),.CLKC2_FPHASE(0)
) u_pll(.refclk(clk_50m),.reset(1'b0),.stdby(1'b0),.extlock(locked),
    .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b000),.psdone(),
    .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'b0),.daddr(6'b0),.do(),.fbclk(mem_clk),
    .clkc({open_c4,open_c3,mem_sft,mem_raw,core_raw}));
wire pixel_clk,serial_clk,pixel_raw;
wire video_unused2,video_unused3,video_unused4;
EG_LOGIC_BUFG u_pixel_clock(.i(pixel_raw),.o(pixel_clk));
EG_PHY_PLL #(
    .FIN("50.000000"),.FEEDBK_MODE("NOCOMP"),.FEEDBK_PATH("VCO_PHASE_0"),
    .DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.STDBY_ENABLE("DISABLE"),
    .PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),
    .GMC_GAIN(4),.ICP_CURRENT(13),.KVCO(4),.LPF_CAPACITOR(1),.LPF_RESISTOR(8),
    .REFCLK_DIV(1),.FBCLK_DIV(30),
    .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(20),.CLKC0_CPHASE(19),.CLKC0_FPHASE(0),
    .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(4),.CLKC1_CPHASE(3),.CLKC1_FPHASE(0)
) u_video_pll(.refclk(clk_50m),.reset(!locked),.stdby(1'b0),.extlock(video_locked),
    .load_reg(1'b0),.psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b000),.psdone(),
    .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'b0),.daddr(6'b0),.do(),.fbclk(1'b0),
    .clkc({video_unused4,video_unused3,video_unused2,serial_clk,pixel_raw}));
wire rst_n,mem_rst_n,pixel_rst_n,init_done;
reset_sync u_reset(.clk(clk),.arst_n(locked&&key_reset_n),.srst_n(rst_n));
reset_sync u_mem_reset(.clk(mem_clk),.arst_n(locked&&key_reset_n),.srst_n(mem_rst_n));
reset_sync u_pixel_reset(.clk(pixel_clk),.arst_n(locked&&video_locked&&key_reset_n&&init_done),.srst_n(pixel_rst_n));
wire [3:0] key_press;
key_debounce u_keys(.clk(clk),.rst_n(rst_n),.key_n({2'b11,key_pause_n,1'b1}),
    .key_level_n(),.key_press_pulse(key_press),.key_release_pulse());
reg pause;
always @(posedge clk or negedge rst_n)if(!rst_n)pause<=0;else if(key_press[1])pause<=!pause;
wire [40:0] media_request;
generate if(OFFLINE_LINK)begin:g_request_cdc
    secondary_offline_request_cdc u_request(.source_clk(clk_50m),.source_rst_n(offline_control_rst_n),
        .source_data(offline_request),.target_clk(clk),.target_rst_n(rst_n),.target_data(media_request));
end else begin:g_standalone_request
    assign media_request={32'd0,8'hff,1'b0};
end endgenerate
wire effective_pause=OFFLINE_LINK?media_request[0]:pause;
wire [55:0] media_status;
generate if(AV_ENABLE)begin:g_status_cdc
    secondary_offline_request_cdc #(.WIDTH(56),.INITIAL(56'd0)) u_status(
        .source_clk(clk_50m),.source_rst_n(offline_control_rst_n),.source_data(offline_status),
        .target_clk(clk),.target_rst_n(rst_n),.target_data(media_status));
end else begin:g_no_status
    assign media_status=0;
end endgenerate

wire card_ready,card_hs,card_done,card_valid,card_busy,card_start;
wire [31:0] card_lba,card_blocks,verified_blocks;
wire [7:0] card_data,card_error,card_stage;
assign sd_dat=4'bzzzz;
sd_native_read u_sd(.clk(clk),.rst_n(rst_n),.read_start(card_start),.read_lba(card_lba),.read_blocks(card_blocks),
    .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat),.initialized(card_ready),.high_speed(card_hs),
    .busy(card_busy),.done(card_done),.data_valid(card_valid),.data(card_data),
    .verified_blocks(verified_blocks),.error(card_error),.stage(card_stage));
wire file_ready,movie_busy,movie_done,movie_start,byte_valid;
wire [7:0] byte_data,file_error,file_stage,frame_error;
wire [31:0] movie_index,movie_frames;
wire reader_rst_n,stream_hold,stream_clear,stream_idle;
wire [63:0] selected_stem;
wire [7:0] active_id;
wire [31:0] active_generation;
wire movie_sd_start,movie_sd_done,movie_sd_valid,subtitle_sd_start,subtitle_sd_done,subtitle_sd_valid;
wire [31:0] movie_sd_lba,movie_sd_blocks,subtitle_sd_lba;
wire shared_sd_busy;
wire pcm_byte_valid,frame_has_audio;
wire [7:0] pcm_byte_data,fs_spc;
wire [31:0] fs_fat,fs_data,fs_root;
wire pcm_accept,core_front_valid;
wire [31:0] core_front_epoch;
wire [31:0] guide_position,guide_start_position;
wire [31:0] resume_frame;
generate if(OFFLINE_LINK)begin:g_file_control
    secondary_offline_file_control u_files(.clk(clk),.rst_n(rst_n),
        .requested_id(media_request[8:1]),.requested_generation(media_request[40:9]),
        .sd_busy(shared_sd_busy),.sd_start(card_start),.frame_idle(stream_idle),.movie_busy(movie_busy),.file_ready(file_ready),
        .stream_hold(stream_hold),.stream_clear(stream_clear),.reader_rst_n(reader_rst_n),
        .selected_stem(selected_stem),.active_id(active_id),.active_generation(active_generation));
end else begin:g_original_file
    assign reader_rst_n=rst_n;assign stream_hold=0;assign stream_clear=0;assign selected_stem=0;
    assign active_id=255;assign active_generation=0;
end endgenerate
generate if(AV_ENABLE)begin:g_sd_arbitration
    offline_sd_arbiter u_arbiter(.clk(clk),.rst_n(rst_n),.video_start(movie_sd_start),
        .video_lba(movie_sd_lba),.video_blocks(movie_sd_blocks),.subtitle_start(subtitle_sd_start),
        .subtitle_lba(subtitle_sd_lba),.video_valid(movie_sd_valid),.video_done(movie_sd_done),
        .subtitle_valid(subtitle_sd_valid),.subtitle_done(subtitle_sd_done),.client_data(),
        .card_start(card_start),.card_lba(card_lba),.card_blocks(card_blocks),
        .card_busy(card_busy),.card_done(card_done),.card_valid(card_valid),.card_data(card_data),
        .card_error(card_error),.busy(shared_sd_busy));
end else begin:g_video_only_sd
    assign card_start=movie_sd_start;assign card_lba=movie_sd_lba;assign card_blocks=movie_sd_blocks;
    assign movie_sd_done=card_done;assign movie_sd_valid=card_valid;assign shared_sd_busy=card_busy;
    assign subtitle_sd_done=0;assign subtitle_sd_valid=0;
end endgenerate
// Localize the movie client's byte/done fanout, as for the subtitle client.
// Keep data and both qualifiers together; CRC errors still abort immediately.
reg movie_valid_q,movie_done_q;
reg [7:0] movie_data_q;
always @(posedge clk)begin
    movie_valid_q<=reader_rst_n&&movie_sd_valid;
    movie_done_q<=reader_rst_n&&movie_sd_done;
    movie_data_q<=card_data;
end
fat32_mvid_reader #(.HEIGHT(VIDEO_HEIGHT),.FPS(VIDEO_FPS),.INPUT_VERSION(OFFLINE_LINK?2:1),
    .DYNAMIC_STEM(OFFLINE_LINK),.SEEK_ENABLE(AV_ENABLE)) u_movie(.clk(clk),.rst_n(reader_rst_n),.card_ready(card_ready),.next_frame(movie_start),
    .selected_stem(selected_stem),.start_frame(resume_frame),.frame_has_audio(frame_has_audio),
    .fs_sectors_per_cluster(fs_spc),.fs_fat_start(fs_fat),.fs_data_start(fs_data),.fs_root_cluster(fs_root),
    .pcm_valid(pcm_byte_valid),.pcm_byte(pcm_byte_data),
    .sd_start(movie_sd_start),.sd_lba(movie_sd_lba),.sd_blocks(movie_sd_blocks),.sd_done(AV_ENABLE?movie_done_q:movie_sd_done),
    .sd_valid(AV_ENABLE?movie_valid_q:movie_sd_valid),.sd_data(AV_ENABLE?movie_data_q:card_data),.sd_error(card_error),.byte_valid(byte_valid),.byte_data(byte_data),
    .ready(file_ready),.frame_busy(movie_busy),.frame_done(movie_done),.frame_index(movie_index),
    .frame_count(movie_frames),.error(file_error),.stage(file_stage));
wire write_req,write_en,write_ack,write_finish,write_full;
wire [20:0] write_base,write_len,display_base;
wire [31:0] write_data,displayed_frames;
wire display_valid,frame_begin;
wire hs,vs,de,frame_tick;
wire [10:0] x;
wire [9:0] y;
wire vblank=x==0&&y==720;
mvid_frame_control #(.FPS(VIDEO_FPS),.FRAME_BYTES(FRAME_BYTES),.VIDEO_BASE(VIDEO_BASE),.STREAM_CONTROL(OFFLINE_LINK),
    .SLOTS(VIDEO_HEIGHT==480?3:2),.THIRD_BASE(FRAME_BYTES/2)) u_frames(.clk(clk),.rst_n(rst_n),.pause(effective_pause),
    .file_ready(file_ready&&(!AV_ENABLE||!frame_has_audio||pcm_accept)),
    .frame_epoch(active_generation),.front_epoch(core_front_epoch),.front_valid(core_front_valid),
    .stream_hold(stream_hold),.stream_clear(stream_clear),.stream_idle(stream_idle),
    .movie_done(movie_done),.byte_valid(byte_valid),.byte_data(byte_data),.input_error(file_error|card_error),
    .movie_start(movie_start),.write_req(write_req),.write_en(write_en),.write_base(write_base),.write_len(write_len),
    .write_data(write_data),.write_ack(write_ack),.write_finish(write_finish),.write_full(write_full),
    .pixel_clk(pixel_clk),.pixel_rst_n(pixel_rst_n),.vblank(vblank),.display_valid(display_valid),
    .frame_begin(frame_begin),.display_base(display_base),.displayed_frames(displayed_frames),.error(frame_error));
wire read_req,read_ack,read_en,fifo_empty,fifo_valid;
wire [20:0] read_base,read_len;
wire [31:0] read_data;
anlogic_frame_store #(.WRITE_BURST_SIZE(128),.READ_BURST_SIZE(64),.READ_LOOP(0),
    .TURNAROUND_CYCLES(8)) u_store(
    .mem_clk(mem_clk),.mem_clk_sft(mem_sft),.rst_n(mem_rst_n),.init_done(init_done),.init_ref_valid(),.mem_busy(),
    .write_clk(clk),.write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),.write_fifo_full(write_full),
    .write_base_addr(write_base),.write_len(write_len),.write_en(write_en),.write_data(write_data),
    .read_clk(pixel_clk),.read_req(read_req),.read_req_ack(read_ack),.read_finish(),
    .read_fifo_valid(fifo_valid),.read_fifo_empty(fifo_empty),.read_base_addr(read_base),.read_len(read_len),
    .read_en(read_en),.read_data(read_data));
video_timing_640x480_pclk #(.H_VISIBLE(1280),.H_FRONT(110),.H_SYNC(40),.H_BACK(220),
    .V_VISIBLE(720),.V_FRONT(5),.V_SYNC(5),.V_BACK(20)) u_timing(
    .clk(pixel_clk),.rst_n(pixel_rst_n),.hs(hs),.vs(vs),.de(de),.x(x),.y(y),.frame_tick(frame_tick));
wire hs_scaled,vs_scaled,de_scaled,underflow;
wire [15:0] pixel;
mvid_scale2x #(.HEIGHT(VIDEO_HEIGHT)) u_scale(.clk(pixel_clk),.rst_n(pixel_rst_n),.frame_begin(frame_begin),.frame_base(display_base),
    .de(de&&display_valid),.hs(hs),.vs(vs),.x(x),.y(y),.read_req(read_req),.read_base(read_base),.read_len(read_len),
    .read_ack(read_ack),.fifo_empty(fifo_empty),.fifo_valid(fifo_valid),.fifo_data(read_data),.read_en(read_en),
    .hs_o(hs_scaled),.vs_o(vs_scaled),.de_o(de_scaled),.pixel(pixel),.underflow(underflow));
wire [23:0] rgb={pixel[15:11],pixel[15:13],pixel[10:5],pixel[10:9],pixel[4:0],pixel[4:2]};
wire hs_final,vs_final,de_final,audio_valid,acr_valid;
wire [23:0] rgb_final;
wire [31:0] audio_data;
wire [19:0] acr_cts,acr_n;
generate if(AV_ENABLE)begin:g_av
    wire pcm_request,pcm_valid,pcm_has_data,pcm_underflow,muted_ack,missed_reply;
    wire [31:0] pcm_data;
    wire [1:0] pcm_error;
    reg [31:0] guide_frame;
    reg [31:0] guide_total_samples,guide_start_samples;
    reg [10:0] sample_in_frame;
    // Keep a frame-accurate guide checkpoint; no variable division in the
    // real-time path. Resume repeats at most the current 33.3ms audio frame.
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin guide_frame<=0;sample_in_frame<=0;end
        else if(stream_clear||!reader_rst_n)sample_in_frame<=0;
        else if(active_id==255&&pcm_valid&&pcm_has_data)begin
            if(sample_in_frame==1599)begin
                sample_in_frame<=0;guide_frame<=guide_frame==movie_frames-1'b1 ? 0 : guide_frame+1'b1;
            end else sample_in_frame<=sample_in_frame+1'b1;
        end
    end
    assign resume_frame=active_id==255?guide_frame:0;
    always @(posedge clk)begin
        guide_total_samples<=(movie_frames<<10)+(movie_frames<<9)+(movie_frames<<6);
        guide_start_samples<=(guide_frame<<10)+(guide_frame<<9)+(guide_frame<<6);
    end
    assign guide_start_position=guide_start_samples;
    wire clear_audio=stream_clear||!reader_rst_n||!file_ready;
    wire consume=frame_has_audio&&core_front_valid&&core_front_epoch==active_generation&&
        !effective_pause&&!stream_hold&&file_error==0&&card_error==0&&frame_error==0;
    mvid_pcm_commit u_pcm(.clk(clk),.rst_n(rst_n),.clear(clear_audio),.frame_begin(movie_start),
        .frame_has_audio(frame_has_audio),.frame_done(movie_done),.frame_abort(file_error!=0||card_error!=0),
        .pcm_valid(pcm_byte_valid),.pcm_byte(pcm_byte_data),.frame_accept(pcm_accept),
        .sample_req(pcm_request),.sample_valid(pcm_valid),.sample_has_data(pcm_has_data),
        .sample_data(pcm_data),.underflow(pcm_underflow),.error(pcm_error));
    offline_audio_output #(.FADE_ENABLE(1)) u_audio(.clk(clk),.rst_n(rst_n),.clear(clear_audio),.consume(consume),
        .unmute(media_status[0]&&pcm_error==0),.epoch(active_generation),
        .total_samples(guide_total_samples),
        .start_position(guide_start_position),.pcm_request(pcm_request),.pcm_valid(pcm_valid),
        .pcm_has_data(pcm_has_data),.pcm_data(pcm_data),.position(guide_position),.muted_ack(muted_ack),
        .pixel_clk(pixel_clk),.pixel_rst_n(pixel_rst_n),.audio_valid(audio_valid),
        .audio_data(audio_data),.missed_reply(missed_reply));
    reg [1:0] muted_sync;
    always @(posedge clk_50m or negedge offline_control_rst_n)
        if(!offline_control_rst_n)muted_sync<=0;else muted_sync<={muted_sync[0],muted_ack};
    assign offline_muted_ack=muted_sync[1];
    audio_arc_calculate u_acr(.clk(pixel_clk),.rst(!pixel_rst_n),.sample_valid(audio_valid),
        .acr_valid(acr_valid),.acr_cts(acr_cts),.acr_n(acr_n));

    wire [31:0] caption_position=active_id==255?guide_position:media_status[55:24];
    reg caption_run;
    always @(posedge clk or negedge rst_n)
        if(!rst_n)caption_run<=0;
        else caption_run<=file_ready&&!stream_hold&&(active_id==255||active_id<=4)&&
            (active_id==255||media_status[1])&&card_error==0&&file_error==0;
    reg [31:0] last_caption_position;
    reg caption_reset;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin last_caption_position<=0;caption_reset<=1;end
        else begin
            last_caption_position<=caption_position;
            if(!caption_run||caption_position<last_caption_position)caption_reset<=1;
            else if(!shared_sd_busy)caption_reset<=0;
        end
    end
    // Coordinates and ungated output DE follow the scaler's two registers.
    reg [10:0] x_d1,x_d2;
    reg [9:0] y_d1,y_d2;
    reg [1:0] de_delay;
    always @(posedge pixel_clk)begin
        x_d1<=x;x_d2<=x_d1;y_d1<=y;y_d2<=y_d1;de_delay<={de_delay[0],de};
    end
    wire hs_sub,vs_sub,de_sub;
    wire [10:0] x_sub;
    wire [9:0] y_sub;
    wire [23:0] rgb_sub;
    wire [23:0] pixel_status;
    secondary_offline_request_cdc #(.WIDTH(24),.INITIAL(24'd0)) u_overlay_state(
        .source_clk(clk),.source_rst_n(rst_n),
        // All admitted frames in this target are 640x480/30. Report a source
        // format only after a complete front frame exists, not the HDMI mode.
        .source_data({6'd0,core_front_valid,core_front_valid&&core_front_epoch==active_generation&&active_id==254,media_status[15:0]}),
        .target_clk(pixel_clk),.target_rst_n(pixel_rst_n),.target_data(pixel_status));
    wire overlay_visible;
    reg subtitle_valid_q,subtitle_done_q;
    reg [7:0] subtitle_data_q;
    always @(posedge clk)begin
        subtitle_valid_q<=subtitle_sd_valid;subtitle_done_q<=subtitle_sd_done;subtitle_data_q<=card_data;
    end
    wire [23:0] rgb_without_sub=display_valid?rgb:24'd0;
    museum_subtitle_overlay #(.PIPE_RAM_OUTPUT(1),.EXTERNAL_VISIBILITY(1),.SCROLL_GUIDE_ONLY(1)) u_subtitles(
        .clk_50m(clk),.rst_n_50m(rst_n),.start(caption_run&&!caption_reset),.restart(caption_reset),
        .lecture_active(caption_run),.lecture_paused(effective_pause),.lecture_finished(1'b0),
        .track_index(active_id==255?3'd5:active_id[2:0]),.audio_frame_index(caption_position),.speed_index(2'd0),
        .sd_init_done(card_ready),.fs_geometry_ready(file_ready),.fs_sectors_per_cluster(fs_spc),
        .fs_fat_start(fs_fat),.fs_data_start(fs_data),.fs_root_cluster(fs_root),
        .sd_sec_read(subtitle_sd_start),.sd_sec_read_addr(subtitle_sd_lba),.sd_sec_read_data(subtitle_data_q),
        .sd_sec_read_data_valid(subtitle_valid_q),.sd_sec_read_end(subtitle_done_q),
        .subtitle_ready(),.subtitle_total_frames(),.scene_timing_valid(),.scene_cut1(),.scene_cut2(),.scene_cut3(),.scene_cut4(),
        .format_error(),.file_error(),.name_wr_en(),.name_wr_addr(),.name_wr_data(),.name_ready(),
        .video_clk(pixel_clk),.video_rst_n(pixel_rst_n),.video_frame_tick(frame_tick),
        .hs_i(hs_scaled),.vs_i(vs_scaled),.de_i(de_delay[1]),.x_i(x_d2),.y_i(y_d2),
        .rgb_i(rgb_without_sub),.visible(overlay_visible),
        .hs_o(hs_sub),.vs_o(vs_sub),.de_o(de_sub),.x_o(x_sub),.y_o(y_sub),.rgb_o(rgb_sub));
    secondary_offline_overlay u_overlay(.clk(pixel_clk),.rst_n(pixel_rst_n),.frame_tick(frame_tick),
        .status(pixel_status),.audio_valid(audio_valid),.audio_data(audio_data),
        .visible(overlay_visible),.hs(hs_sub),.vs(vs_sub),.de(de_sub),.x(x_sub),.y(y_sub),.rgb(rgb_sub),
        .hs_o(hs_final),.vs_o(vs_final),.de_o(de_final),.rgb_o(rgb_final));
end else begin:g_silent
    assign pcm_accept=1;assign resume_frame=0;assign guide_start_position=0;assign guide_position=0;
    assign subtitle_sd_start=0;assign subtitle_sd_lba=0;assign offline_muted_ack=1;
    assign audio_valid=0;assign audio_data=0;assign acr_valid=0;assign acr_cts=0;assign acr_n=6144;
    assign hs_final=hs_scaled;assign vs_final=vs_scaled;assign de_final=de_scaled;assign rgb_final=rgb;
end endgenerate
wire [7:0] pairs;
secondary_hdmi_local_pairs #(.HDMI_PACKETS(AV_ENABLE),.AUDIO_ENABLE(AV_ENABLE)) u_encoder(
    .pixel_clk(pixel_clk),.serial_clk(serial_clk),.rst_n(pixel_rst_n),
    .hs(~hs_final),.vs(~vs_final),.de(de_final),.rgb(rgb_final),.pairs(pairs),
    .audio_valid(audio_valid),.audio_data(audio_data),.acr_valid(acr_valid),.acr_cts(acr_cts),.acr_n(acr_n),
    .encoder_ready(),.encoder_blank(),.symbols());
wire [3:0] serial_out;
assign {hdmi_b_clk_p,hdmi_b_d2_p,hdmi_b_d1_p,hdmi_b_d0_p}=serial_out;
genvar lane;
generate for(lane=0;lane<4;lane=lane+1)begin:g_output
    EG_LOGIC_ODDR u_output(.q(serial_out[lane]),.clk(serial_clk),.rst(!pixel_rst_n),
        .d0(pairs[lane*2]),.d1(pairs[lane*2+1]));
end endgenerate
reg [27:0] heartbeat;
reg [1:0] display_sync,underflow_sync,init_sync;
always @(posedge clk or negedge rst_n)
    if(!rst_n)begin heartbeat<=0;display_sync<=0;underflow_sync<=0;init_sync<=0;end
    else begin heartbeat<=heartbeat+1'b1;display_sync<={display_sync[0],display_valid};
        underflow_sync<={underflow_sync[0],underflow};init_sync<={init_sync[0],init_done};end
wire any_error=card_error!=0||file_error!=0||frame_error!=0||underflow_sync[1];
assign led={any_error,display_sync[1],file_ready,heartbeat[25]};
// D is a diagnostic count only; unlike ownership handshakes it is not used
// for control across clocks. It may be sampled while a digit is changing.
wire [31:0] displayed=card_error!=0?{8'hf0,card_stage,8'h00,card_error}:
    file_error!=0?{8'hf1,file_stage,8'h00,file_error}:
    frame_error!=0?{24'hf20000,frame_error}:underflow_sync[1]?32'hf3000001:
    !file_ready?{8'ha0,card_stage,file_stage,8'h00}:
    heartbeat[27:26]==0?{24'ha00000,3'd0,pause,display_sync[1],init_sync[1],card_hs,card_ready}:
    heartbeat[27:26]==1?{8'hb0,movie_index[23:0]}:
    heartbeat[27:26]==2?{8'hc0,movie_frames[23:0]}:{8'hd0,displayed_frames[23:0]};
function [7:0] segments;
    input [3:0] digit;
    begin case(digit)
        0:segments=8'hc0;1:segments=8'hf9;2:segments=8'ha4;3:segments=8'hb0;
        4:segments=8'h99;5:segments=8'h92;6:segments=8'h82;7:segments=8'hf8;
        8:segments=8'h80;9:segments=8'h90;10:segments=8'h88;11:segments=8'h83;
        12:segments=8'hc6;13:segments=8'ha1;14:segments=8'h86;default:segments=8'h8e;
    endcase end
endfunction
always @* begin seg_sel=~(8'b1<<heartbeat[16:14]);
    seg_data=segments((displayed>>(heartbeat[16:14]*4))&4'hf);end
endmodule
`default_nettype wire
