vlib work
vlog ../src/ethernet/mbp1_codec.v ../src/ethernet/mbp1_main_endpoint.v tb_mbp1_main_endpoint.v
vsim -c -gENABLE_CONTROL=1 tb_mbp1_main_endpoint -do "run -all; quit -f"
