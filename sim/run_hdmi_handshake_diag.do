onerror {quit -code 1 -f}
if {[file exists work_hdmi_handshake]} {vdel -lib work_hdmi_handshake -all}
vlib work_hdmi_handshake
vlog -work work_hdmi_handshake D:/TD_6.2.1/sim_release/eg4/eg_logic_iobuf.v D:/TD_6.2.1/sim_release/eg4/eg_phy_glbl.v
vlog -work work_hdmi_handshake ../src/common/seg_hex_display.v ../src/input/key_debounce.v ../src/secondary/top_secondary_hdmi_handshake_diag.v tb_hdmi_handshake_diag.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_handshake tb_hdmi_handshake_diag glbl
run -all
if {[examine -radix unsigned /tb_hdmi_handshake_diag/test_pass] != 1} {quit -code 1 -f}
quit -f
