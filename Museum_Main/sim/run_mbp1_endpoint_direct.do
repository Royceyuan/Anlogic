vlib work_mbp1_direct
vmap work work_mbp1_direct
vlog -work work_mbp1_direct ../src/ethernet/mbp1_codec.v ../src/ethernet/mbp1_main_endpoint.v tb_mbp1_main_endpoint.v
vsim -c -lib work_mbp1_direct tb_mbp1_main_endpoint -gENABLE_CONTROL=1 -gHOLD_TX_FIELDS=0 -do "run -all; quit -f"
