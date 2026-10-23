onerror {quit -code 1 -f}
set library work_offline_hdmi_audio
vlib $library
set td D:/TD_6.2.1/sim_release/eg4
vlog -work $library {*}[glob $td/*.v]
vcom -2008 -work $library ../vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/SerializerN_1_lvds_dat.enc.vhd
vlog -work $library ../vendor/official_ref/lab_ex5_i2s_audio_hdmi/hdmi_1_4b_transmitter_core_wrapper.enc.v ../src/audio/audio_arc_calculate.v ../src/video/secondary_hdmi_packet_symbols.v ../src/video/secondary_hdmi_symbol_pairs.v ../src/video/secondary_hdmi_local_pairs.v ../src/video/secondary_hdmi_source_switch.v tb_secondary_hdmi_packet_symbols.v
vsim -c -voptargs=+acc -onfinish stop -gAUDIO_TEST=1 -lib $library tb_secondary_hdmi_packet_symbols glbl
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_packet_symbols/test_pass] != 1} {quit -code 1 -f}
quit -f
