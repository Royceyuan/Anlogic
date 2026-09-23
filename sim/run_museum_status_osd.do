if {[file exists work_main3_osd]} {vdel -lib work_main3_osd -all}
vlib work_main3_osd
vlog +define+SIM -work work_main3_osd ../src/video/uart_subtitle_overlay.v ../src/video/museum_status_osd.v tb_museum_status_osd.v
vsim -c -lib work_main3_osd tb_museum_status_osd -do "run -all; quit -f"
