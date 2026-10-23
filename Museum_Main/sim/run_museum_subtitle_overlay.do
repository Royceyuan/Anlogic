if {[file exists work_museum_subtitle]} {vdel -lib work_museum_subtitle -all}
vlib work_museum_subtitle
vmap work work_museum_subtitle
vlog +define+SIM +incdir+.. -work work_museum_subtitle ../src/video/uart_subtitle_overlay.v ../src/video/museum_subtitle_overlay.v tb_museum_subtitle_overlay.v
vsim -c -lib work_museum_subtitle tb_museum_subtitle_overlay -do "run -all; quit -f"
