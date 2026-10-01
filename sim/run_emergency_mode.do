onerror {quit -code 1 -f}
if {[file exists work_main4_emergency]} {vdel -lib work_main4_emergency -all}
vlib work_main4_emergency
vmap work work_main4_emergency
vlog +define+SIM -work work_main4_emergency ../src/video/museum_emergency_overlay.v tb_museum_emergency_overlay.v
vsim -c -voptargs=+acc -onfinish stop -lib work_main4_emergency tb_museum_emergency_overlay
run -all
if {[examine -radix binary /tb_museum_emergency_overlay/test_pass] ne "1"} {quit -code 1 -f}
quit -f
