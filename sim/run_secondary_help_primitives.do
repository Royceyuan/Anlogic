onerror {quit -code 1 -f}
if {[file exists work_secondary_help_phy]} {vdel -lib work_secondary_help_phy -all}
vlib work_secondary_help_phy
set td_sim D:/TD_6.2.1/sim_release/eg4
if {![file exists $td_sim/eg_phy_bram32k.v]} {set td_sim D:/Anlogic/TD5.6.2/sim_release/eg4}
vlog -work work_secondary_help_phy $td_sim/eg_phy_bram32k.v $td_sim/eg_phy_bram.v $td_sim/eg_logic_bram.v
vlog -work work_secondary_help_phy $td_sim/eg_phy_glbl.v
vlog +incdir+.. -work work_secondary_help_phy ../src/secondary/secondary_help_overlay.v tb_secondary_help_overlay.v
vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_help_phy tb_secondary_help_overlay glbl
run -all
if {[examine -radix unsigned /tb_secondary_help_overlay/test_pass] != 1} {quit -code 1 -f}
quit -f
