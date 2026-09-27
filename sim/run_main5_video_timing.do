onerror {quit -code 1 -f}
if {[file exists work_main5_video_timing]} {vdel -lib work_main5_video_timing -all}
vlib work_main5_video_timing
set source [exec git show 62ee8bf:src/video/museum_status_osd.v]
set source [string map {"module museum_status_osd (" "module museum_status_osd_ref ("} $source]
set fd [open work_main5_video_timing/museum_status_osd_ref.v w]
puts $fd $source
close $fd
vlog +define+SIM -work work_main5_video_timing ../src/storage/al_dp_ram32.v ../src/video/linebuf_scaler_960x540_to_1280x720.v tb_linebuf_scaler_zoom.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_status_osd.v work_main5_video_timing/museum_status_osd_ref.v tb_main5_osd_equivalence.v
vsim -c -voptargs=+acc -onfinish stop -lib work_main5_video_timing tb_linebuf_scaler_zoom
run -all
if {[examine -radix binary /tb_linebuf_scaler_zoom/test_pass] ne "1"} {quit -code 1 -f}
quit -sim
vsim -c -voptargs=+acc -onfinish stop -lib work_main5_video_timing tb_main5_osd_equivalence
run -all
if {[examine -radix binary /tb_main5_osd_equivalence/test_pass] ne "1"} {quit -code 1 -f}
quit -f
