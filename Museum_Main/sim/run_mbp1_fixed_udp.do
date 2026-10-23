vlib work
vlog ../src/ethernet/mbp1_fixed_udp.v tb_mbp1_fixed_udp.v
vsim -c tb_mbp1_fixed_udp
run -all
quit -f
