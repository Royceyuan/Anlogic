if {[file exists work_secondary_main5e_endpoint]} {vdel -lib work_secondary_main5e_endpoint -all}
vlib work_secondary_main5e_endpoint
vlog -work work_secondary_main5e_endpoint ../src/ethernet/mbp1_codec.v ../src/ethernet/mbp1_secondary_endpoint.v tb_mbp1_secondary_endpoint.v
vsim -c -onfinish stop -lib work_secondary_main5e_endpoint tb_mbp1_secondary_endpoint
run -all
quit -f
