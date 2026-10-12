onerror {quit -code 1 -f}
if {[file exists work_hdmi_latency]} {vdel -lib work_hdmi_latency -all}
vlib work_hdmi_latency
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_latency {*}[glob $td/*.v]
vlog -work work_hdmi_latency ../src/video/secondary_hdmi_source_switch.v tb_secondary_hdmi_source_switch.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_latency tb_secondary_hdmi_source_switch glbl -gSETTLE_CYCLES=50000
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_source_switch/test_pass] != 1} {quit -code 1 -f}
quit -f
