if {[file exists work_main3_names]} {vdel -lib work_main3_names -all}
vlib work_main3_names
vlog +define+SIM -work work_main3_names ../src/video/uart_subtitle_overlay.v ../src/video/museum_subtitle_overlay.v tb_museum_name_loader.v
vsim -c -lib work_main3_names tb_museum_name_loader -gMODE=0
run -all
vsim -c -lib work_main3_names tb_museum_name_loader -gMODE=1
run -all
vsim -c -lib work_main3_names tb_museum_name_loader -gMODE=2
run -all
quit -f
