onerror {quit -code 1 -f}
if {[file exists work_hdmi_pad]} {vdel -lib work_hdmi_pad -all}
vlib work_hdmi_pad
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_pad {*}[glob $td/*.v]
vlog -work work_hdmi_pad ../src/video/hdmi_relay_phy.v tb_hdmi_relay_pad.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_pad tb_hdmi_relay_pad glbl
run -all
if {[examine -radix unsigned /tb_hdmi_relay_pad/test_pass] != 1} {quit -code 1 -f}
quit -f
