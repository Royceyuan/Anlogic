onerror {quit -code 1 -f}
if {[file exists work_pc_local]} {vdel -lib work_pc_local -all}
vlib work_pc_local
vlog -work work_pc_local ../src/secondary/top_secondary_main5e.v ../src/secondary/secondary_carousel_controller.v tb_secondary_pc_local_policy.v
vsim -c -voptargs=+acc -onfinish stop -lib work_pc_local tb_secondary_pc_local_policy
run -all
if {[examine -radix unsigned /tb_secondary_pc_local_policy/test_pass] != 1} {quit -code 1 -f}
quit -f
