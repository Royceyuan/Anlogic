if {[file exists work_secondary_main5e_udp]} {vdel -lib work_secondary_main5e_udp -all}
vlib work_secondary_main5e_udp
vlog -work work_secondary_main5e_udp ../src/ethernet/mbp1_fixed_udp.v tb_mbp1_fixed_udp.v
vsim -c -onfinish stop -lib work_secondary_main5e_udp tb_mbp1_fixed_udp -gSECONDARY=0
run -all
quit -sim
vsim -c -onfinish stop -lib work_secondary_main5e_udp tb_mbp1_fixed_udp -gSECONDARY=1
run -all
quit -f
