`timescale 1ns / 1ps
module tb_museum_subtitle_overlay;
reg clk50=0,vclk=0,rst50=0,vrst=0,start=0,restart=0,active=0,finished=0;
reg frame_tick=0,hs=1,vs=1,de=1,sd_init=1;
reg [2:0] track=0;
reg [31:0] audio_frame=0;
reg [10:0] x=636;
reg [9:0] y=676;
reg [23:0] rgb=24'h345678;
reg [7:0] sd_data=0;
reg sd_valid=0,sd_end=0;
wire sd_read,ready,fmt_error,file_error,hs_o,vs_o,de_o;
wire [31:0] sd_addr,total_frames;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;
always #10 clk50=~clk50;
always #5 vclk=~vclk;

museum_subtitle_overlay dut(
 .clk_50m(clk50),.rst_n_50m(rst50),.start(start),.restart(restart),
 .lecture_active(active),.lecture_finished(finished),.track_index(track),
 .audio_frame_index(audio_frame),.sd_init_done(sd_init),
 .fs_geometry_ready(1'b1),.fs_sectors_per_cluster(8'd8),
 .fs_fat_start(32'd33),.fs_data_start(32'd35),.fs_root_cluster(32'd2),
 .sd_sec_read(sd_read),.sd_sec_read_addr(sd_addr),.sd_sec_read_data(sd_data),
 .sd_sec_read_data_valid(sd_valid),.sd_sec_read_end(sd_end),
 .subtitle_ready(ready),.subtitle_total_frames(total_frames),
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
   35: case(index)
       0:disk_byte="S";1:disk_byte="U";2:disk_byte="B";3:disk_byte="0";
       4,5,6,7:disk_byte=" ";8:disk_byte="B";9:disk_byte="I";10:disk_byte="N";
       11:disk_byte=8'h20;26:disk_byte=3;29:disk_byte=8'h10;
      endcase
   43: case(index)
       0:disk_byte="M";1:disk_byte="S";2:disk_byte="U";3:disk_byte="B";
       4:disk_byte=1;5:disk_byte=8'h20;6:disk_byte=8'h03;7:disk_byte=32;
       8:disk_byte=1;9:disk_byte=1;10:disk_byte=8'h80;11:disk_byte=8'h0c;
       12:disk_byte=7;16:disk_byte=100;
      endcase
   44: case(index)
       4:disk_byte=100;8:disk_byte=8;
       16:disk_byte=8'h80;
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

integer i;
initial begin
 repeat(3)@(negedge clk50);rst50=1;vrst=1;start=1;
 i=0;
 while(!ready && i<100000) begin @(negedge clk50);i=i+1;end
 if(!ready)$fatal(1,"TF subtitle timeout state=%0d addr=%0d",dut.state,sd_addr);
 if(total_frames!=100||fmt_error||file_error)$fatal(1,"bad SUB header");
 active=1;audio_frame=1;
 repeat(20)@(negedge clk50);
 for(i=0;i<45;i=i+1) begin
  @(negedge vclk);frame_tick=1;@(negedge vclk);frame_tick=0;
 end
 repeat(5)@(negedge vclk);
 if(rgb_o!==24'hFFF1C7)$fatal(1,"TF subtitle pixel missing: %h",rgb_o);
 audio_frame=100;repeat(8)@(negedge vclk);
 if(rgb_o!==rgb)$fatal(1,"expired subtitle changed image: %h",rgb_o);
 $display("PASS tb_museum_subtitle_overlay");$finish;
end
endmodule
