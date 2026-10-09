onerror {quit -code 1 -f}
if {[file exists work_hdmi_diag]} {vdel -lib work_hdmi_diag -all}
vlib work_hdmi_diag
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_diag $td/eg_logic_clk.v $td/eg_phy_pll.v $td/eg_logic_io.v $td/eg_phy_glbl.v
vlog -work work_hdmi_diag ../src/common/reset_sync.v ../src/common/seg_hex_display.v ../src/clock/hdmi_relay_clock.v ../src/video/hdmi_edid_720p.v ../src/video/hdmi_relay_phy.v ../src/video/hdmi_tmds_monitor.v ../src/secondary/top_secondary_hdmi_relay_diag.v tb_hdmi_relay_diag.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_diag tb_hdmi_relay_diag glbl
run -all
if {[examine -radix unsigned /tb_hdmi_relay_diag/test_pass] != 1} {quit -code 1 -f}
quit -f
