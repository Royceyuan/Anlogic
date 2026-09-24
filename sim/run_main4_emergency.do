if {[file exists work_main4_emergency]} {vdel -lib work_main4_emergency -all}
vlib work_main4_emergency
vmap work work_main4_emergency
vlog +define+SIM -work work_main4_emergency ../src/video/museum_emergency_overlay.v tb_museum_emergency_overlay.v
vsim -c -lib work_main4_emergency tb_museum_emergency_overlay
run -all
quit -f
