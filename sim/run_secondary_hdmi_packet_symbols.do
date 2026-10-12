onerror {quit -code 1 -f}
if {[file exists work_hdmi_packets]} {vdel -lib work_hdmi_packets -all}
vlib work_hdmi_packets
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_hdmi_packets {*}[glob $td/*.v]
vcom -2008 -work work_hdmi_packets ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/SerializerN_1_lvds_dat.enc.vhd
vlog -work work_hdmi_packets ../vendor/official_ref/lab_ex5_i2s_audio_hdmi/hdmi_1_4b_transmitter_core_wrapper.enc.v ../src/video/secondary_hdmi_packet_symbols.v ../src/video/secondary_hdmi_local_pairs.v ../src/video/secondary_hdmi_source_switch.v tb_secondary_hdmi_packet_symbols.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_packets tb_secondary_hdmi_packet_symbols glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_packet_symbols/test_pass] != 1} {quit -code 1 -f}
quit -f
