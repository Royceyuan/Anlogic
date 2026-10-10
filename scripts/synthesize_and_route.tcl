import_device eagle_s20.db -package EG4S20BG256
set secondary_root .
set project dual_fpga_museum_terminal_secondary_board.al
set top top_secondary_hdmi_museum
set sdc constraints/secondary_hdmi_museum.sdc
set adc constraints/secondary_hdmi_museum.adc
set secondary_build [file join $secondary_root build]
if {[info exists ::env(SECONDARY_BUILD)]} {set secondary_build $::env(SECONDARY_BUILD)}
file mkdir $secondary_build
cd $secondary_root
open_project [file join $secondary_root $project] -single_run
load_run_param -run syn_1
elaborate -top $top
read_adc [file join $secondary_root $adc]
clear_sdc -user
read_sdc [file join $secondary_root $sdc]
optimize_rtl
report_area -file [file join $secondary_build secondary_main5e_rtl.area]
optimize_gate -packarea [file join $secondary_build secondary_main5e_gate.area]
legalize_phy_inst
update_timing
report_timing_status -file [file join $secondary_build secondary_main5e_gate.ts]
report_timing_summary -file [file join $secondary_build secondary_main5e_gate.timing]
flow_status -file [file join $secondary_build secondary_main5e_syn.status]
export_db [file join $secondary_build secondary_main5e_gate.db]

set place_seed 7
set pair_regions {0 8 1 12}
# Keep real half-cycle paths near their source IOLs; no timing exceptions.
foreach {lane origin_y} $pair_regions {
    set pair_cells [get_cells -hier -regexp [format {u_relay/u_phy/g_lane\[%d\].*(transmit_pair|output_pair).*} $lane]]
    puts "AV lane$lane pair cells: $pair_cells"
    if {[llength $pair_cells]!=6} {error "AV lane$lane pair placement no longer matches the netlist"}
    create_bound av_lane${lane}_pairs -mode fixed -width 2 -height 4 -origin [list 38 $origin_y]
    add_cells_to_bound -bound av_lane${lane}_pairs -cells $pair_cells
}
set_param place seed $place_seed
place
update_timing -mode manhattan
report_area -io_info -file [file join $secondary_build secondary_main5e_place.area]
report_timing_summary -file [file join $secondary_build secondary_main5e_place.timing]
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_area -io_info -file [file join $secondary_build secondary_main5e_final.area]
report_qor -step route -file [file join $secondary_build secondary_main5e_final.qor]
report_timing_status -file [file join $secondary_build secondary_main5e_final.ts]
report_timing_summary -file [file join $secondary_build secondary_main5e_final.timing]
report_timing_exception -file [file join $secondary_build secondary_main5e_exception.timing]
flow_status -file [file join $secondary_build secondary_main5e_pr.status]
export_db [file join $secondary_build secondary_main5e_pr.db]
exit
