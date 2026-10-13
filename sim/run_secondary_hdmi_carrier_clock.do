onerror {quit -code 1 -f}
if {[file exists work_hdmi_carrier]} {vdel -lib work_hdmi_carrier -all}
vlib work_hdmi_carrier
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_carrier {*}[glob $td/*.v]
vcom -2008 -work work_hdmi_carrier ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/SerializerN_1_lvds_dat.enc.vhd
vlog -work work_hdmi_carrier ../src/video/secondary_hdmi_carrier_clock.v ../src/video/secondary_hdmi_symbol_pairs.v tb_secondary_hdmi_carrier_clock.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_carrier tb_secondary_hdmi_carrier_clock glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_carrier_clock/test_pass] != 1} {quit -code 1 -f}
quit -f
