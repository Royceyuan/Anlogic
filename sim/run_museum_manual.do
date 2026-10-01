vlib work_manual
vlog -work work_manual ../src/video/museum_lecture_controller.v tb_museum_lecture_controller.v
vsim -novopt -c -lib work_manual tb_museum_lecture_controller -gMANUAL_TEST=1
run -all
quit -f
