onerror {quit -code 1 -f}
if {[file exists work_hdmi_pll_model]} {vdel -lib work_hdmi_pll_model -all}
vlib work_hdmi_pll_model
vlog -work work_hdmi_pll_model {*}[glob D:/TD_6.2.1/sim_release/eg4/*.v]
vlog -work work_hdmi_pll_model ../src/clock/hdmi_relay_clock.v tb_secondary_hdmi_pll_model.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_pll_model tb_secondary_hdmi_pll_model glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_pll_model/test_pass] != 1} {quit -code 1 -f}
quit -f
