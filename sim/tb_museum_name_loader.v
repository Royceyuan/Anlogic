`timescale 1ns / 1ps
module tb_museum_name_loader #(
 parameter integer MODE=0 // 0 valid/fragmented, 1 missing, 2 corrupt header
);
reg clk=0,rst_n=0,start=1,sd_valid=0,sd_end=0;
reg [7:0] sd_data=0;
wire sd_read,name_we,name_ready;
wire [31:0] sd_addr;
wire [10:0] name_addr;
wire [7:0] name_data;
integer writes=0;
always #10 clk=~clk;
museum_subtitle_overlay #(.ENABLE_NAMES(1)) dut (
 .clk_50m(clk),.rst_n_50m(rst_n),.start(start),.restart(1'b0),
 .lecture_active(1'b0),.lecture_paused(1'b0),.lecture_finished(1'b0),
 .track_index(3'd0),.audio_frame_index(32'd0),.sd_init_done(1'b1),
 .fs_geometry_ready(1'b1),.fs_sectors_per_cluster(8'd2),
 .fs_fat_start(32'd33),.fs_data_start(32'd35),.fs_root_cluster(32'd2),
 .sd_sec_read(sd_read),.sd_sec_read_addr(sd_addr),
 .sd_sec_read_data(sd_data),.sd_sec_read_data_valid(sd_valid),
 .sd_sec_read_end(sd_end),
 .name_wr_en(name_we),.name_wr_addr(name_addr),
 .name_wr_data(name_data),.name_ready(name_ready),
 .subtitle_ready(),.subtitle_total_frames(),.scene_timing_valid(),
 .scene_cut1(),.scene_cut2(),.scene_cut3(),.scene_cut4(),
 .format_error(),.file_error(),
 .video_clk(clk),.video_rst_n(rst_n),.video_frame_tick(1'b0),
 .hs_i(1'b1),.vs_i(1'b1),.de_i(1'b0),
 .x_i(11'd0),.y_i(10'd0),.rgb_i(24'd0),
 .hs_o(),.vs_o(),.de_o(),.x_o(),.y_o(),.rgb_o()
);
function [7:0] disk_byte;
 input [31:0] sector;
 input [8:0] index;
 begin
  disk_byte=0;
  case(sector)
   35:if(MODE!=1) case(index)
      0:disk_byte="O";1:disk_byte="S";2:disk_byte="D";
      3:disk_byte="N";4:disk_byte="A";5:disk_byte="M";
      6:disk_byte="E";7:disk_byte=" ";8:disk_byte="B";
      9:disk_byte="I";10:disk_byte="N";
      11:disk_byte=8'h20;26:disk_byte=4;29:disk_byte=12;
     endcase
   33:case(index)
      16:disk_byte=7;28:disk_byte=9;
     endcase
   39:case(index)
      0:disk_byte="O";1:disk_byte="N";
      2:disk_byte="A";3:disk_byte="M";
      4:disk_byte=MODE==2 ? 2 : 1;
      5:disk_byte=5;6:disk_byte=160;
      8:disk_byte=16;9:disk_byte=1;11:disk_byte=12;
     endcase
   40,45,46,49,50:if(index<320) disk_byte=index[7:0] ^ sector[7:0];
  endcase
 end
endfunction
reg reading=0,request_seen=0;
reg [31:0] sector=0;
reg [8:0] index=0;
always @(posedge clk) begin
 sd_valid<=0;sd_end<=0;
 if(!sd_read) request_seen<=0;
 if(!reading && sd_read && !request_seen) begin
  reading<=1;request_seen<=1;sector<=sd_addr;index<=0;
 end else if(reading) begin
  sd_valid<=1;sd_data<=disk_byte(sector,index);
  if(index==511) begin reading<=0;sd_end<=1;end
  else index<=index+1'b1;
 end
 if(name_we) begin
  if(name_addr!==writes[10:0])
   $fatal(1,"name address %d expected %d",name_addr,writes);
  writes=writes+1;
 end
end
integer timeout;
initial begin
 repeat(3) @(negedge clk);rst_n=1;
 timeout=0;
 while(dut.name_mode && timeout<100000) begin @(negedge clk);timeout=timeout+1; end
 if(timeout>=100000 || (MODE==0 && (!name_ready || writes!=1600)) ||
    (MODE!=0 && (name_ready || writes!=0)))
  $fatal(1,"names mode=%d failed: ready=%b writes=%d",MODE,name_ready,writes);
 $display("PASS tb_museum_name_loader mode=%d ready=%b writes=%d",MODE,name_ready,writes);
    $stop;
end
endmodule
