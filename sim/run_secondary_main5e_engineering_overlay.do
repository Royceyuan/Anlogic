if {[file exists work_secondary_main5e_engineering]} {vdel -lib work_secondary_main5e_engineering -all}
vlib work_secondary_main5e_engineering
vlog -work work_secondary_main5e_engineering ../src/secondary/secondary_main5e_engineering_overlay.v tb_secondary_main5e_engineering_overlay.v
vsim -c -onfinish stop -lib work_secondary_main5e_engineering tb_secondary_main5e_engineering_overlay
run -all
quit -f
