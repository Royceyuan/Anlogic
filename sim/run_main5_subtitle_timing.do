onerror {quit -code 1 -f}
if {[file exists work_main5_subtitle_timing]} {vdel -lib work_main5_subtitle_timing -all}
vlib work_main5_subtitle_timing
set source [exec git show 62ee8bf:src/video/museum_subtitle_overlay.v]
set source [string map {"module museum_subtitle_overlay #(" "module museum_subtitle_overlay_ref #("} $source]
set fd [open work_main5_subtitle_timing/reference.v w]
puts $fd $source
close $fd
# Reuse the actual FAT/lecture/restart stimulus against the old pixel path.
set fd [open tb_museum_subtitle_overlay.v r]
set bench [read $fd]
close $fd
regexp {museum_subtitle_overlay #\(\.PIPE_RAM_OUTPUT\(PIPE_RAM_OUTPUT\)\) dut\(.*?\);} $bench instance
# The instance ends at the first port-list terminator, before the disk model.
if {![info exists instance]} {error "subtitle instance not found"}
set instance [string map {"museum_subtitle_overlay #(.PIPE_RAM_OUTPUT(PIPE_RAM_OUTPUT)) dut(" "museum_subtitle_overlay_ref ref_dut("} $instance]
regsub -all {\((sd_read|sd_addr|ready|total_frames|scene_valid|scene_cut1|scene_cut2|scene_cut3|scene_cut4|fmt_error|file_error|hs_o|vs_o|de_o|x_o|y_o|rgb_o)\)} $instance {(\1_ref)} instance
set checks {
wire sd_read_ref,ready_ref,scene_valid_ref,fmt_error_ref,file_error_ref;
wire hs_o_ref,vs_o_ref,de_o_ref;
wire [31:0] sd_addr_ref,total_frames_ref,scene_cut1_ref,scene_cut2_ref,scene_cut3_ref,scene_cut4_ref;
wire [10:0] x_o_ref;
wire [9:0] y_o_ref;
wire [23:0] rgb_o_ref;
wire [47:0] ref_pixels={hs_o_ref,vs_o_ref,de_o_ref,x_o_ref,y_o_ref,rgb_o_ref};
reg [47:0] delayed_ref;
integer checked_pixels=0;
always @(posedge vclk) delayed_ref<=ref_pixels;
always @(negedge vclk) begin
 if(vrst) checked_pixels=checked_pixels+1;
 if(checked_pixels>6 && {hs_o,vs_o,de_o,x_o,y_o,rgb_o} !==
    (PIPE_RAM_OUTPUT ? delayed_ref : ref_pixels))
   $fatal(1,"subtitle pixel/metadata changed with PIPE_RAM_OUTPUT=%d",PIPE_RAM_OUTPUT);
 if(vrst && dut.current_center !== ((1280-dut.current_width)>>1))
   $fatal(1,"cached subtitle center mismatch");
end
always @(negedge clk50)
 if(rst50 && {sd_read,sd_addr,ready,total_frames,scene_valid,scene_cut1,scene_cut2,
              scene_cut3,scene_cut4,fmt_error,file_error} !==
             {sd_read_ref,sd_addr_ref,ready_ref,total_frames_ref,scene_valid_ref,
              scene_cut1_ref,scene_cut2_ref,scene_cut3_ref,scene_cut4_ref,fmt_error_ref,file_error_ref})
   $fatal(1,"subtitle reader/timeline changed");
}
set bench [string map [list "endmodule" "$checks\n$instance\nendmodule"] $bench]
set scan {
 for(i=0;i<10000;i=i+1) begin
   @(negedge vclk);
   x=620+($random & 63);y=660+($random & 63);
   rgb=$random;de=$random;hs=$random;vs=$random;
 end
 repeat(5) @(negedge vclk);
 test_pass=1;
}
set bench [string map [list "test_pass=1;" $scan] $bench]
set fd [open work_main5_subtitle_timing/bench.v w]
puts $fd $bench
close $fd
vlog +define+SIM -work work_main5_subtitle_timing ../src/video/uart_subtitle_overlay.v ../src/video/museum_subtitle_overlay.v work_main5_subtitle_timing/reference.v work_main5_subtitle_timing/bench.v
foreach pipe {0 1} {
    vsim -c -voptargs=+acc -onfinish stop -lib work_main5_subtitle_timing tb_museum_subtitle_overlay -gPIPE_RAM_OUTPUT=$pipe
    run -all
    if {[examine -radix binary /tb_museum_subtitle_overlay/test_pass] ne "1"} {quit -code 1 -f}
    quit -sim
}
quit -f
