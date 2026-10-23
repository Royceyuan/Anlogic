transcript on
if {[file exists work_main2_lecture]} {vdel -lib work_main2_lecture -all}
vlib work_main2_lecture
vmap work work_main2_lecture
vlog ../src/video/museum_lecture_controller.v ../sim/tb_museum_lecture_controller.v
vsim -c tb_museum_lecture_controller -do "run -all; quit -f"
