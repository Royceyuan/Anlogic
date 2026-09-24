if {[file exists work_secondary_transition]} {vdel -lib work_secondary_transition -all}
vlib work_secondary_transition
vlog -work work_secondary_transition ../src/video/transition_theme_controller.v ../src/video/video_transition_mask.v ../src/video/video_fade.v tb_transition_theme_controller.v tb_video_transition_mask.v
vsim -c -onfinish stop -lib work_secondary_transition tb_transition_theme_controller
run -all
quit -sim
vsim -c -onfinish stop -lib work_secondary_transition tb_video_transition_mask
run -all
quit -f
