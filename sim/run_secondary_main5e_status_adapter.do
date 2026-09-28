if {[file exists work_secondary_main5e_status]} {vdel -lib work_secondary_main5e_status -all}
vlib work_secondary_main5e_status
vlog -work work_secondary_main5e_status ../src/secondary/secondary_main5e_status_adapter.v ../src/secondary/secondary_carousel_controller.v tb_secondary_main5e_status_adapter.v
vsim -c -onfinish stop -lib work_secondary_main5e_status tb_secondary_main5e_status_adapter
run -all
quit -f
