onerror {quit -code 1 -f}
if {[file exists work_hdmi_ingress]} {vdel -lib work_hdmi_ingress -all}
vlib work_hdmi_ingress
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_ingress {*}[glob $td/*.v]
vcom -2008 -work work_hdmi_ingress ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/TMDSEncoder.enc.vhd
vlog -work work_hdmi_ingress ../src/common/uart_byte_io.v ../src/common/reset_sync.v ../src/common/seg_hex_display.v ../src/secondary/secondary_video_uart_control.v ../src/clock/hdmi_relay_clock.v ../src/video/hdmi_edid_720p.v ../src/video/hdmi_relay_phy.v ../src/video/hdmi_tmds_monitor.v ../vendor/official_hdmi_loop_edid/myedid_new.v ../vendor/official_hdmi_loop_edid/i2c_edid.v ../vendor/official_hdmi_loop_edid/i2cSlaveTop.v ../vendor/anlogic_lab6/al_ip/afifo_32_16_256.v ../src/video/secondary_hdmi_symbol_buffer.v ../src/video/secondary_hdmi_frame_handoff.v ../src/video/secondary_hdmi_carrier_clock.v ../src/video/secondary_hdmi_pc_raster.v ../src/video/secondary_hdmi_common_symbols.v ../src/video/secondary_hdmi_symbol_pairs.v ../src/video/secondary_hdmi_local_pairs.v ../src/video/secondary_hdmi_source_switch.v secondary_hdmi_museum_media_stub.v ../src/secondary/top_secondary_hdmi_museum.v
vlog -sv -work work_hdmi_ingress tb_secondary_hdmi_common_ingress.v
vlog -work work_hdmi_ingress ../src/secondary/top_secondary_hdmi_relay_diag.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_ingress tb_secondary_hdmi_common_ingress glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_common_ingress/test_pass] != 1} {quit -code 1 -f}
quit -f
