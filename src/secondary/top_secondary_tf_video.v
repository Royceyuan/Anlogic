`timescale 1ns/1ps
`default_nettype none
`ifndef TF_VIDEO_FPS
`define TF_VIDEO_FPS 30
`endif
`ifndef TF_VIDEO_HEIGHT
`define TF_VIDEO_HEIGHT 360
`endif
// Standalone offline-video acceptance top. Does not replace the museum top.
module top_secondary_tf_video(
    input wire clk_50m,key_reset_n,key_pause_n,
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
fat32_mvid_reader #(.HEIGHT(VIDEO_HEIGHT),.FPS(VIDEO_FPS)) u_movie(.clk(clk),.rst_n(rst_n),.card_ready(card_ready),.next_frame(movie_start),
    .sd_start(card_start),.sd_lba(card_lba),.sd_blocks(card_blocks),.sd_done(card_done),
    .sd_valid(card_valid),.sd_data(card_data),.sd_error(card_error),.byte_valid(byte_valid),.byte_data(byte_data),
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
mvid_frame_control #(.FPS(VIDEO_FPS),.FRAME_BYTES(FRAME_BYTES),.VIDEO_BASE(VIDEO_BASE),
    .SLOTS(VIDEO_HEIGHT==480?3:2),.THIRD_BASE(FRAME_BYTES/2)) u_frames(.clk(clk),.rst_n(rst_n),.pause(pause),.file_ready(file_ready),
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
wire [7:0] pairs;
secondary_hdmi_local_pairs u_encoder(.pixel_clk(pixel_clk),.serial_clk(serial_clk),.rst_n(pixel_rst_n),
    .hs(~hs_scaled),.vs(~vs_scaled),.de(de_scaled),.rgb(rgb),.pairs(pairs),
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
