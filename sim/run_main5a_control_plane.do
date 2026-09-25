vlib work
vlog +define+SIM ../src/ethernet/mdio_clause22_monitor.v ../src/ethernet/udp_echo_buffer.v tb_main5a_control_plane.v
vsim -c tb_main5a_control_plane -do "run -all; quit -f"
