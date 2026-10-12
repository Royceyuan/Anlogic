onerror {quit -code 1 -f}
if {[file exists work_hdmi_handoff]} {vdel -lib work_hdmi_handoff -all}
vlib work_hdmi_handoff
vlog -work work_hdmi_handoff ../src/video/secondary_hdmi_frame_handoff.v
vlog -sv -work work_hdmi_handoff tb_secondary_hdmi_frame_handoff.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_handoff tb_secondary_hdmi_frame_handoff
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_frame_handoff/test_pass] != 1} {quit -code 1 -f}
quit -f
