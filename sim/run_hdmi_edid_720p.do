onerror {quit -code 1 -f}
if {[file exists work_hdmi_edid]} {vdel -lib work_hdmi_edid -all}
vlib work_hdmi_edid
vlog -work work_hdmi_edid ../src/video/hdmi_edid_720p.v tb_hdmi_edid_720p.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_edid tb_hdmi_edid_720p
run -all
if {[examine -radix unsigned /tb_hdmi_edid_720p/test_pass] != 1} {quit -code 1 -f}
quit -f
