onerror {quit -code 1 -f}
if {[file exists work_hdmi_common]} {vdel -lib work_hdmi_common -all}
vlib work_hdmi_common
vcom -2008 -work work_hdmi_common ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/TMDSEncoder.enc.vhd
vlog +define+SIM+COMMON_HDMI_TEST +incdir+.. -work work_hdmi_common ../src/common/reset_sync.v ../src/common/seg_hex_display.v ../src/input/key_debounce.v ../src/video/video_timing_640x480_pclk.v ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v ../src/storage/fat32_image_loader.v ../src/storage/adaptive_row_ram.v ../src/storage/al_dp_ram16.v ../src/storage/bmp_row_buffer.v ../src/storage/bmp_sdram_row_writer.v ../src/storage/rgb565_stream_packer_ready.v ../src/video/rgb888_adjust.v ../src/video/video_fade.v ../src/video/video_transition_mask.v ../src/video/transition_theme_controller.v ../src/video/product_show_controller.v ../src/secondary/secondary_carousel_controller.v ../src/secondary/secondary_page_overlay.v ../src/secondary/secondary_help_overlay.v ../src/memory/sdram_bmp_row_top_v66.v secondary_help_physical_stubs.v ../src/video/secondary_hdmi_pc_raster.v ../src/video/secondary_hdmi_common_symbols.v ../src/video/secondary_hdmi_frame_handoff.v
vlog -sv -work work_hdmi_common tb_secondary_hdmi_common_output.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_common tb_secondary_hdmi_common_output
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_common_output/test_pass] != 1} {quit -code 1 -f}
quit -f
