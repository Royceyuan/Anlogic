onerror {quit -code 1 -f}
if {[file exists work_hdmi_local]} {vdel -lib work_hdmi_local -all}
vlib work_hdmi_local
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_local {*}[glob $td/*.v]
vcom -2008 -work work_hdmi_local ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/TMDSEncoder.enc.vhd ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/SerializerN_1_lvds_dat.enc.vhd
vlog -work work_hdmi_local ../src/video/secondary_hdmi_local_pairs.v ../src/video/secondary_hdmi_source_switch.v tb_secondary_hdmi_local_pairs.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_local tb_secondary_hdmi_local_pairs glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_local_pairs/test_pass] != 1} {quit -code 1 -f}
quit -f
