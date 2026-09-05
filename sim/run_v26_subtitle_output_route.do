if {[file exists work_v26_subtitle_route]} {vdel -lib work_v26_subtitle_route -all}
vlib work_v26_subtitle_route
vlog +define+SIM -work work_v26_subtitle_route ../src/common/reset_sync.v
vlog +define+SIM -work work_v26_subtitle_route ../src/storage/al_dp_ram32.v
vlog +define+SIM -work work_v26_subtitle_route ../src/video/video_timing_640x480_pclk.v
vlog +define+SIM -work work_v26_subtitle_route ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v
vlog +define+SIM -work work_v26_subtitle_route ../src/video/rgb888_adjust.v
vlog +define+SIM -work work_v26_subtitle_route ../src/video/video_fade.v
vlog +define+SIM -work work_v26_subtitle_route ../src/video/linebuf_scaler_960x540_to_1280x720.v
vlog +define+SIM -work work_v26_subtitle_route ../src/video/video_transition_mask.v
vlog +define+SIM -work work_v26_subtitle_route ../src/video/uart_subtitle_overlay.v
vlog +define+SIM -work work_v26_subtitle_route ../src/memory/sdram_bmp_row_top_v66.v
vlog +define+SIM +define+STUB_STORE +define+V66_TOP -work work_v26_subtitle_route tb_sdram_bmp_row_top_chain.v
vsim -novopt -c -lib work_v26_subtitle_route tb_sdram_bmp_row_top_chain -gTEST_V26_OUTPUT_PIPELINE=1 -gOUTPUT_ROUTE_TEST=1
run -all
quit -f
