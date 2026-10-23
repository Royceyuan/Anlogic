if {[file exists work_sd_read_abort]} {vdel -lib work_sd_read_abort -all}
vlib work_sd_read_abort
vmap work work_sd_read_abort
vlog +define+SIM -work work_sd_read_abort ../src/common/reset_sync.v ../src/storage/al_dp_ram32.v ../src/video/video_timing_programmable_pclk.v ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v ../src/video/rgb888_adjust.v ../src/video/video_fade.v ../src/video/linebuf_scaler_960x540_to_1280x720.v ../src/video/video_transition_mask.v ../src/video/transition_theme_controller.v ../src/video/product_show_controller.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_emergency_overlay.v ../src/memory/museum_media_core.v
vlog +define+SIM +define+STUB_STORE +define+V66_TOP -work work_sd_read_abort tb_museum_media_core.v
vsim -novopt -c -lib work_sd_read_abort tb_museum_media_core -gSD_ABORT_TEST=1
run -all
quit -f
