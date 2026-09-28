if {[file exists work_secondary_main5e_codec]} {vdel -lib work_secondary_main5e_codec -all}
vlib work_secondary_main5e_codec
vlog -work work_secondary_main5e_codec ../src/ethernet/mbp1_codec.v tb_mbp1_codec.v
vsim -c -onfinish stop -lib work_secondary_main5e_codec tb_mbp1_codec
run -all
quit -f
