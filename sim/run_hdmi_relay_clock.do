onerror {quit -code 1 -f}
if {[file exists work_hdmi_clock]} {vdel -lib work_hdmi_clock -all}
vlib work_hdmi_clock
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_clock $td/eg_logic_clk.v $td/eg_phy_clk.v $td/eg_phy_pll.v $td/eg_logic_io.v $td/eg_phy_glbl.v
vlog -work work_hdmi_clock ../src/clock/hdmi_relay_clock.v ../src/video/hdmi_relay_phy.v tb_hdmi_relay_clock.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_clock tb_hdmi_relay_clock glbl
run -all
if {[examine -radix unsigned /tb_hdmi_relay_clock/test_pass] != 1} {quit -code 1 -f}
quit -f
