onerror {quit -code 1 -f}
if {[file exists work_hdmi_av]} {vdel -lib work_hdmi_av -all}
vlib work_hdmi_av
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_av {*}[glob $td/*.v]
vlog -work work_hdmi_av ../src/common/reset_sync.v ../src/common/seg_hex_display.v ../src/clock/hdmi_relay_clock.v ../src/video/hdmi_edid_720p.v ../src/video/hdmi_relay_phy.v ../src/video/hdmi_tmds_monitor.v ../vendor/official_hdmi_loop_edid/myedid_new.v ../vendor/official_hdmi_loop_edid/i2c_edid.v ../vendor/official_hdmi_loop_edid/i2cSlaveTop.v ../src/secondary/top_secondary_hdmi_relay_diag.v top_secondary_hdmi_av_reference.v tb_secondary_hdmi_av_diag.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_av tb_secondary_hdmi_av_diag glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_av_diag/test_pass] != 1} {quit -code 1 -f}
quit -f
