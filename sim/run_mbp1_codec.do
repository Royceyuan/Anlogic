vlib work
vlog ../src/ethernet/mbp1_codec.v tb_mbp1_codec.v
vsim -c tb_mbp1_codec -do "run -all; quit -f"
