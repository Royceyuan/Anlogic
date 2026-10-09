onerror {quit -code 1 -f}
if {[file exists work_hdmi_monitor]} {vdel -lib work_hdmi_monitor -all}
vlib work_hdmi_monitor
vlog -work work_hdmi_monitor ../src/video/hdmi_tmds_monitor.v tb_hdmi_tmds_monitor.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_monitor tb_hdmi_tmds_monitor
run -all
if {[examine -radix unsigned /tb_hdmi_tmds_monitor/test_pass] != 1} {quit -code 1 -f}
quit -sim
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_monitor tb_hdmi_tmds_monitor -gPC_PAYLOAD=1
run -all
if {[examine -radix unsigned /tb_hdmi_tmds_monitor/test_pass] != 1} {quit -code 1 -f}
quit -f
