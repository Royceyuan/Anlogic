onerror {quit -code 1 -f}
if {[file exists work_hdmi_phy]} {vdel -lib work_hdmi_phy -all}
vlib work_hdmi_phy
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_phy $td/eg_logic_io.v $td/eg_phy_glbl.v
vlog -work work_hdmi_phy ../src/video/hdmi_relay_phy.v tb_hdmi_relay_phy.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_phy tb_hdmi_relay_phy glbl
run -all
if {[examine -radix unsigned /tb_hdmi_relay_phy/test_pass] != 1} {quit -code 1 -f}
quit -f
