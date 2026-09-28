if {[file exists work_secondary_main5e_keys]} {vdel -lib work_secondary_main5e_keys -all}
vlib work_secondary_main5e_keys
vlog -work work_secondary_main5e_keys ../src/input/key_debounce.v ../src/secondary/secondary_main5e_keys.v tb_secondary_main5e_keys.v
vsim -c -onfinish stop -lib work_secondary_main5e_keys tb_secondary_main5e_keys
run -all
quit -f
