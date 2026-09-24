if {[file exists work_main3_zoom]} {vdel -lib work_main3_zoom -all}
vlib work_main3_zoom
vmap work work_main3_zoom
vlog +define+SIM -work work_main3_zoom ../src/common/reset_sync.v ../src/storage/al_dp_ram32.v ../src/video/video_timing_640x480_pclk.v ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v ../src/video/rgb888_adjust.v ../src/video/video_fade.v ../src/video/linebuf_scaler_960x540_to_1280x720.v ../src/video/video_transition_mask.v ../src/video/transition_theme_controller.v ../src/video/product_show_controller.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_overview_controller.v ../src/video/museum_lecture_controller.v ../src/video/museum_overview_overlay.v ../src/video/museum_status_osd.v ../src/memory/sdram_bmp_row_top_v66.v
vlog +define+SIM +define+STUB_STORE +define+V66_TOP -work work_main3_zoom tb_sdram_bmp_row_top_chain.v
vsim -novopt -c -lib work_main3_zoom tb_sdram_bmp_row_top_chain -gMAIN3_ZOOM_TEST=1
run -all
quit -f
