import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5d_control]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_museum_terminal.al] -single_run
load_run_param -run syn_1
elaborate -top top_main5d_control
create_clock -name clk_50m -period 20 [get_ports {clk_50m}]
create_clock -name eth_rgmii_rx_clk -period 8 [get_ports {eth_rgmii_rx_clk}]
derive_pll_clocks
optimize_rtl
report_area -file [file join $build_root main5d_rtl.area]
optimize_gate -packarea [file join $build_root main5d_gate.area]
exit
