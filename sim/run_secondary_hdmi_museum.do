onerror {quit -code 1 -f}
if {[file exists work_hdmi_museum]} {vdel -lib work_hdmi_museum -all}
vlib work_hdmi_museum
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_museum {*}[glob $td/*.v]
vcom -2008 -work work_hdmi_museum ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/TMDSEncoder.enc.vhd
vlog -work work_hdmi_museum ../src/common/reset_sync.v ../src/common/seg_hex_display.v ../src/clock/hdmi_relay_clock.v ../src/video/hdmi_edid_720p.v ../src/video/hdmi_relay_phy.v ../src/video/hdmi_tmds_monitor.v ../vendor/official_hdmi_loop_edid/myedid_new.v ../vendor/official_hdmi_loop_edid/i2c_edid.v ../vendor/official_hdmi_loop_edid/i2cSlaveTop.v ../src/secondary/top_secondary_hdmi_relay_diag.v ../src/video/secondary_hdmi_local_pairs.v ../src/video/secondary_hdmi_source_switch.v secondary_hdmi_museum_media_stub.v ../src/secondary/top_secondary_hdmi_museum.v tb_secondary_hdmi_museum.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_museum tb_secondary_hdmi_museum glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_museum/test_pass] != 1} {quit -code 1 -f}
quit -f
