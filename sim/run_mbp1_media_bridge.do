vlib work
vlog ../src/ethernet/mbp1_media_bridge.v tb_mbp1_media_bridge.v
vsim -c tb_mbp1_media_bridge
run -all
quit -f
