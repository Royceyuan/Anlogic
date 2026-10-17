onerror {quit -code 1 -f}
if {[file exists work_secondary_main5e_keys]} {vdel -lib work_secondary_main5e_keys -all}
vlib work_secondary_main5e_keys
vlog -work work_secondary_main5e_keys ../src/input/key_debounce.v ../src/secondary/secondary_main5e_keys.v tb_secondary_main5e_keys.v
vsim -novopt -c -onfinish stop -lib work_secondary_main5e_keys tb_secondary_main5e_keys
run -all
if {[examine -radix unsigned sim:/tb_secondary_main5e_keys/passed]!=1} {quit -code 1 -f}
quit -code 0 -f
