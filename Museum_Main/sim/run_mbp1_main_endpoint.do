vlib work
vlog ../src/ethernet/mbp1_codec.v ../src/ethernet/mbp1_main_endpoint.v tb_mbp1_main_endpoint.v
vsim -c tb_mbp1_main_endpoint -do "run -all; quit -f"
