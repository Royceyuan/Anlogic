onerror {quit -code 1 -f}
if {[file exists work_secondary_shared_clock]} {vdel -lib work_secondary_shared_clock -all}
vlib work_secondary_shared_clock
set td D:/TD_6.2.1/sim_release/eg4
vlog -work work_secondary_shared_clock $td/eg_logic_clk.v $td/eg_phy_pll.v $td/eg_phy_glbl.v
vlog -work work_secondary_shared_clock ../src/clock/secondary_media_eth_pll.v ../src/clock/sys_pll_50m_phase144_native720.v ../vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/pll_gen.v tb_secondary_shared_clock.v
vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_shared_clock tb_secondary_shared_clock glbl
run -all
if {[examine -radix unsigned /tb_secondary_shared_clock/test_pass] != 1} {quit -code 1 -f}
quit -f
