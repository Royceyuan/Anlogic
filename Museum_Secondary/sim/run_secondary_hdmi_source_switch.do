onerror {quit -code 1 -f}
if {[file exists work_hdmi_switch]} {vdel -lib work_hdmi_switch -all}
vlib work_hdmi_switch
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_switch {*}[glob $td/*.v]
vlog -work work_hdmi_switch ../src/video/secondary_hdmi_source_switch.v tb_secondary_hdmi_source_switch.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_switch tb_secondary_hdmi_source_switch glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_source_switch/test_pass] != 1} {quit -code 1 -f}
quit -f
