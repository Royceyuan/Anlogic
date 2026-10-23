`timescale 1ns / 1ps
module tb_museum_subtitle_overlay #(parameter PIPE_RAM_OUTPUT=0, parameter SPEED_TEST=0);
reg test_pass=0;
reg clk50=0,vclk=0,rst50=0,vrst=0,start=0,restart=0,active=0,finished=0;
reg frame_tick=0,hs=1,vs=1,de=1,sd_init=1;
reg [2:0] track=1;
reg [31:0] audio_frame=0;
reg paused=0;
reg [1:0] speed_index=0;
reg [10:0] x=636;
reg [9:0] y=676;
reg [23:0] rgb=24'h345678;
reg [7:0] sd_data=0;
reg sd_valid=0,sd_end=0;
wire sd_read,ready,fmt_error,file_error,hs_o,vs_o,de_o;
wire [31:0] sd_addr,total_frames;
wire scene_valid;
wire [31:0] scene_cut1,scene_cut2,scene_cut3,scene_cut4;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;
always #10 clk50=~clk50;
always #6.666 vclk=~vclk;

museum_subtitle_overlay #(.PIPE_RAM_OUTPUT(PIPE_RAM_OUTPUT),.ENABLE_SPEED(SPEED_TEST)) dut(
 .clk_50m(clk50),.rst_n_50m(rst50),.start(start),.restart(restart),
 .lecture_active(active),.lecture_paused(paused),.lecture_finished(finished),.track_index(track),
 .name_wr_en(),.name_wr_addr(),.name_wr_data(),.name_ready(),
 .audio_frame_index(audio_frame),.speed_index(speed_index),.sd_init_done(sd_init),
 .fs_geometry_ready(1'b1),.fs_sectors_per_cluster(8'd8),
 .fs_fat_start(32'd33),.fs_data_start(32'd35),.fs_root_cluster(32'd2),
 .sd_sec_read(sd_read),.sd_sec_read_addr(sd_addr),.sd_sec_read_data(sd_data),
 .sd_sec_read_data_valid(sd_valid),.sd_sec_read_end(sd_end),
 .subtitle_ready(ready),.subtitle_total_frames(total_frames),
 .scene_timing_valid(scene_valid),
 .scene_cut1(scene_cut1),.scene_cut2(scene_cut2),.scene_cut3(scene_cut3),.scene_cut4(scene_cut4),
 .format_error(fmt_error),.file_error(file_error),
 .video_clk(vclk),.video_rst_n(vrst),.video_frame_tick(frame_tick),
 .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb),
 .hs_o(hs_o),.vs_o(vs_o),.de_o(de_o),.x_o(x_o),.y_o(y_o),.rgb_o(rgb_o));

function [7:0] disk_byte;
 input [31:0] sector;
 input [8:0] index;
 begin
  disk_byte=0;
  case(sector)
   // Root cluster 2 is deliberately empty.  Its FAT entry points at cluster 3,
   // where SUB1.BIN lives; this catches the board failure caused by scanning
   // only the first root-directory cluster.
   33: case(index)
       8:disk_byte=3;16:disk_byte=5;20:disk_byte=6;
       24:disk_byte=7;28:disk_byte=8;
      endcase
   43: case(index)
       0:disk_byte="S";1:disk_byte="U";2:disk_byte="B";3:disk_byte="1";
       4,5,6,7:disk_byte=" ";8:disk_byte="B";9:disk_byte="I";10:disk_byte="N";
       11:disk_byte=8'h20;26:disk_byte=4;29:disk_byte=8'h36;
      endcase
   51: case(index)
       0:disk_byte="M";1:disk_byte="S";2:disk_byte="U";3:disk_byte="B";
       4:disk_byte=3;5:disk_byte=8'h20;6:disk_byte=8'h03;7:disk_byte=32;
       8:disk_byte=2;9:disk_byte=2;10:disk_byte=8'h00;11:disk_byte=8'h19;
       12:disk_byte=13;16:disk_byte=100;
       20:disk_byte=10;24:disk_byte=20;28:disk_byte=30;32:disk_byte=40;
      endcase
   52: case(index)
       4:disk_byte=100;8:disk_byte=8;
       16:disk_byte=8'h80;
      endcase
   58: case(index)
       144:disk_byte=8'h40;
      endcase
   65: case(index)
       0:disk_byte=100;4:disk_byte=200;8:disk_byte=8;
       16:disk_byte=8'h80;
      endcase
   71: case(index)
       144:disk_byte=8'h40;
      endcase
  endcase
 end
endfunction

reg reading=0;
reg request_seen=0;
reg [31:0] read_sector=0;
reg [8:0] read_index=0;
always @(posedge clk50) begin
 sd_valid<=0;sd_end<=0;
 if(!sd_read) request_seen<=0;
 if(!reading && sd_read && !request_seen) begin
  reading<=1;request_seen<=1;read_sector<=sd_addr;read_index<=0;
 end else if(reading) begin
  sd_valid<=1;sd_data<=disk_byte(read_sector,read_index);
  if(read_index==511) begin reading<=0;sd_end<=1;end
  else read_index<=read_index+1'b1;
 end
end

integer i,expected_fade;
initial begin
 repeat(3)@(negedge clk50);rst50=1;vrst=1;start=1;
 i=0;
 while(!ready && i<100000) begin @(negedge clk50);i=i+1;end
 if(!ready)$fatal(1,"TF subtitle timeout state=%0d addr=%0d",dut.state,sd_addr);
 if(total_frames!=100||fmt_error||file_error)$fatal(1,"bad SUB header");
 if(!scene_valid||scene_cut1!=10||scene_cut2!=20||scene_cut3!=30||scene_cut4!=40)
  $fatal(1,"bad scene metadata");
 active=1;audio_frame=1;
 i=0;
 while(dut.state!=13 && i<1000) begin @(negedge clk50);i=i+1;end
 if(dut.state!=13)$fatal(1,"first subtitle commit did not start");
 active=0;start=0;restart=1;@(negedge clk50);restart=0;
 repeat(4)@(negedge vclk);start=1;
 if(ready)$fatal(1,"early restart did not invalidate old subtitle");
 i=0;
 while(!ready && i<100000) begin @(negedge clk50);i=i+1;end
 if(!ready)$fatal(1,"subtitle did not reload after early exit");
 active=1;audio_frame=1;
 repeat(20)@(negedge clk50);
 for(i=0;i<45;i=i+1) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 end
 repeat(5)@(negedge vclk);
 if(rgb_o!==24'hffffff)$fatal(1,"TF subtitle body is not white: %h",rgb_o);
 x=637;repeat(4)@(negedge vclk);
 if(rgb_o!==24'h000000)$fatal(1,"TF subtitle outline is not black: %h",rgb_o);
 x=500;repeat(4)@(negedge vclk);
 if(rgb_o!==rgb)$fatal(1,"subtitle background is not transparent: %h",rgb_o);
 x=636;repeat(4)@(negedge vclk);
 i=0;
 while((dut.cue_index!=1 || !dut.cue_ready) && i<100000) begin
  @(negedge clk50);i=i+1;
 end
 if(!dut.cue_ready)$fatal(1,"second cue was not prefetched");
 audio_frame=100;repeat(8)@(negedge vclk);
 for(i=0;i<9;i=i+1) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 end
 repeat(4)@(negedge vclk);
 if(dut.fade_level==0||dut.fade_level==16)$fatal(1,"outgoing cue did not fade");
 if(SPEED_TEST) begin
  paused=1;repeat(4)@(negedge vclk);speed_index=2;
  expected_fade=dut.fade_level;
  repeat(4) begin @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;end
  if(dut.fade_level!=expected_fade)$fatal(1,"paused speed change advanced subtitle fade");
  paused=0;repeat(4)@(negedge vclk);
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
  if(dut.fade_level!=expected_fade-3)$fatal(1,"3x subtitle fade did not advance three levels");
 end
 i=0;
 while(dut.fade_phase!=2 && i<20) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;i=i+1;
 end
 if(dut.fade_phase!=2||dut.fade_level!=0)$fatal(1,"incoming fade did not start");
 repeat(4)@(negedge vclk);
 if(rgb_o!==rgb)$fatal(1,"subtitle did not fade out: %h",rgb_o);
 for(i=0;i<17;i=i+1) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 end
 repeat(5)@(negedge vclk);
 if(rgb_o!==24'hffffff)$fatal(1,"second cue is not white: %h",rgb_o);
 audio_frame=200;repeat(8)@(negedge vclk);
 if(rgb_o!==rgb)$fatal(1,"expired subtitle changed image: %h",rgb_o);
 @(negedge clk50);active=0;start=0;audio_frame=0;restart=1;
 @(negedge clk50);restart=0;
 repeat(4)@(negedge vclk);start=1;
 if(ready)$fatal(1,"repeat restart did not invalidate old subtitle");
 i=0;
 while(!ready && i<100000) begin @(negedge clk50);i=i+1;end
 if(!ready)$fatal(1,"subtitle did not reload for repeated lecture");
 active=1;audio_frame=1;
 for(i=0;i<45;i=i+1) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 end
 repeat(5)@(negedge vclk);
 if(rgb_o!==24'hffffff)$fatal(1,"repeated lecture subtitle is not white: %h",rgb_o);
 // KEY4 resets the 50 MHz reader, but video timing keeps running.  A cancel
 // sampled before the reader reset must still retire the old commit toggle.
 i=0;
 while((dut.cue_index!=1 || !dut.cue_ready) && i<100000) begin
  @(negedge clk50);i=i+1;
 end
 if(!dut.cue_ready)$fatal(1,"KEY4 setup did not prefetch second cue");
 audio_frame=100;
 repeat(8)@(negedge vclk);
 @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 repeat(5)@(negedge vclk);
 active=0;start=0;
 repeat(5)@(negedge vclk);
 if(dut.commit_toggle!==1'b1 || dut.commit_seen!==1'b1)
  $fatal(1,"KEY4 setup did not leave a pending odd commit: toggle=%b seen=%b",
         dut.commit_toggle,dut.commit_seen);
 rst50=0;
 repeat(6)@(negedge vclk);
 rst50=1;
 repeat(6)@(negedge vclk);
 if(dut.commit_seen!==dut.commit_sync2)
  $fatal(1,"KEY4 left stale video commit state: seen=%b sync=%b",
         dut.commit_seen,dut.commit_sync2);
 repeat(520)@(negedge clk50);
 start=1;audio_frame=0;
 i=0;
 while(!ready && i<100000) begin @(negedge clk50);i=i+1;end
 if(!ready)$fatal(1,"subtitle did not reload after KEY4");
 active=1;audio_frame=1;
 for(i=0;i<45;i=i+1) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 end
 repeat(5)@(negedge vclk);
 if(rgb_o!==24'hffffff)$fatal(1,"KEY4 recovery subtitle is not white: %h",rgb_o);
 test_pass=1;
 $display("PASS tb_museum_subtitle_overlay");$finish;
end
endmodule
