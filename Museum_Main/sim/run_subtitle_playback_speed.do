onerror {quit -code 1 -f}
if {[file exists work_subtitle_speed]} {vdel -lib work_subtitle_speed -all}
vlib work_subtitle_speed
vlog +define+SIM -work work_subtitle_speed ../src/video/uart_subtitle_overlay.v ../src/video/museum_subtitle_overlay.v tb_museum_subtitle_overlay.v
vsim -novopt -onfinish stop -lib work_subtitle_speed tb_museum_subtitle_overlay -gSPEED_TEST=1 -gPIPE_RAM_OUTPUT=1
run -all
if {[examine -radix unsigned /tb_museum_subtitle_overlay/test_pass] != 1} {quit -code 1 -f}
quit -f
