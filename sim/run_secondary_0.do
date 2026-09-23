if {[file exists work_secondary_0]} {vdel -lib work_secondary_0 -all}
vlib work_secondary_0
vlog -work work_secondary_0 ../src/video/video_timing_1280x720_pclk.v ../src/video/hdmi_1280x720_pattern.v tb_secondary_0_timing.v
vsim -c -onfinish stop -lib work_secondary_0 tb_secondary_0_timing
run -all
quit -f
