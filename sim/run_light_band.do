onerror {quit -code 1 -f}
if {[file exists work_light_band]} {vdel -lib work_light_band -all}
vlib work_light_band
vlog +define+SIM -work work_light_band ../src/common/reset_sync.v ../src/storage/al_dp_ram32.v ../src/video/video_timing_programmable_pclk.v ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v ../src/video/rgb888_adjust.v ../src/video/rgb888_picture_adjust.v ../src/video/video_fade.v ../src/video/linebuf_scaler_960x540_to_1280x720.v ../src/video/video_transition_mask.v ../src/video/transition_theme_controller.v ../src/video/product_show_controller.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_overview_controller.v ../src/video/museum_lecture_controller.v ../src/video/museum_overview_overlay.v ../src/video/museum_status_osd.v ../src/video/museum_emergency_overlay.v ../src/memory/museum_media_core.v
vlog +define+SIM +define+STUB_STORE +define+V66_TOP -work work_light_band tb_museum_media_core.v tb_video_light_band.v
vsim -novopt -onfinish stop -lib work_light_band tb_video_light_band
run -all
if {[examine -radix unsigned /tb_video_light_band/passed] != 1} {quit -code 1 -f}
quit -sim
vsim -novopt -onfinish stop -lib work_light_band tb_museum_media_core -gMAIN5_REMOTE_TEST=1 -gLIGHT_BAND_TEST=1
run -all
if {[examine -radix unsigned /tb_museum_media_core/light_band_pass] != 1} {quit -code 1 -f}
quit -f
