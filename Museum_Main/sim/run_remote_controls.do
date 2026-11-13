if {[file exists work_main5_remote]} {vdel -lib work_main5_remote -all}
vlib work_main5_remote
vmap work work_main5_remote
vlog +define+SIM -work work_main5_remote ../src/common/reset_sync.v ../src/storage/al_dp_ram32.v ../src/storage/museum_entry_sector_cache.v ../src/video/video_timing_programmable_pclk.v ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v ../src/video/rgb888_adjust.v ../src/video/rgb888_picture_adjust.v ../src/video/video_fade.v ../src/video/linebuf_scaler_960x540_to_1280x720.v ../src/video/video_transition_mask.v ../src/video/transition_theme_controller.v ../src/video/product_show_controller.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_overview_controller.v ../src/video/museum_lecture_controller.v ../src/video/museum_overview_overlay.v ../src/video/museum_status_osd.v ../src/video/museum_emergency_overlay.v ../src/memory/museum_media_core.v
vlog +define+SIM +define+STUB_STORE +define+V66_TOP -work work_main5_remote tb_museum_media_core.v
if {![info exists local_manual_test]} {set local_manual_test 0}
if {![info exists key4_transition_test]} {set key4_transition_test 0}
if {![info exists slot_reuse_test]} {set slot_reuse_test 0}
if {![info exists key4_opening_test]} {set key4_opening_test 0}
vsim -novopt -c -onfinish stop -lib work_main5_remote tb_museum_media_core -gMAIN5_REMOTE_TEST=1 -gLOCAL_MANUAL_TEST=$local_manual_test -gKEY4_TRANSITION_TEST=$key4_transition_test -gSLOT_REUSE_TEST=$slot_reuse_test -gKEY4_OPENING_TEST=$key4_opening_test
run -all
if {$key4_transition_test && [examine -radix unsigned sim:/tb_museum_media_core/key4_transition_pass]!=1} {quit -code 1 -f}
quit -f
