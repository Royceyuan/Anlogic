onerror {quit -code 1 -f}
if {[file exists work_color_adjust]} {vdel -lib work_color_adjust -all}
vlib work_color_adjust
vlog -work work_color_adjust ../src/video/rgb888_picture_adjust.v tb_rgb888_picture_adjust.v
vsim -novopt -onfinish stop -lib work_color_adjust tb_rgb888_picture_adjust
run -all
if {[examine -radix unsigned /tb_rgb888_picture_adjust/test_pass] != 1} {quit -code 1 -f}
quit -f
