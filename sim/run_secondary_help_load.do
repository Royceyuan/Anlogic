onerror {quit -code 1 -f}
if {[file exists work_secondary_help_load]} {vdel -lib work_secondary_help_load -all}
vlib work_secondary_help_load
vlog -work work_secondary_help_load ../src/storage/rgb565_stream_packer_ready.v
vlog +define+SIM +incdir+.. -work work_secondary_help_load ../src/common/reset_sync.v ../src/common/seg_hex_display.v ../src/input/key_debounce.v ../src/video/video_timing_640x480_pclk.v ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v ../src/storage/fat32_image_loader.v ../src/storage/adaptive_row_ram.v ../src/storage/al_dp_ram16.v ../src/storage/bmp_row_buffer.v ../src/storage/bmp_sdram_row_writer.v ../src/video/rgb888_adjust.v ../src/video/video_fade.v ../src/video/video_transition_mask.v ../src/video/transition_theme_controller.v ../src/video/product_show_controller.v ../src/secondary/secondary_carousel_controller.v ../src/secondary/secondary_page_overlay.v ../src/secondary/secondary_help_overlay.v ../src/memory/sdram_bmp_row_top_v66.v secondary_help_physical_stubs.v tb_secondary_help_load.v
vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_help_load tb_secondary_help_load
run -all
if {[examine -radix unsigned /tb_secondary_help_load/test_pass] != 1} {quit -code 1 -f}
quit -f
