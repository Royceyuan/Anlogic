import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5a_ethernet_diag]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_main5a_ethernet_diag.al] -single_run
load_run_param -run syn_1
elaborate -top top_main5a_ethernet_diag
read_adc [file join $project_root constraints top_main5a_ethernet_diag.adc]
clear_sdc -user
read_sdc [file join $project_root constraints top_main5a_ethernet_diag.sdc]
optimize_rtl
report_area -file [file join $build_root main5a_ethernet_diag_rtl.area]
optimize_gate -packarea [file join $build_root main5a_ethernet_diag_gate.area]
legalize_phy_inst
update_timing
report_timing_status -file [file join $build_root main5a_ethernet_diag_gate.ts]
report_timing_summary -file [file join $build_root main5a_ethernet_diag_gate.timing]
flow_status -file [file join $build_root main5a_ethernet_diag_syn.status]
export_db [file join $build_root main5a_ethernet_diag_gate.db]
place
update_timing -mode manhattan
report_area -io_info -file [file join $build_root main5a_ethernet_diag_place.area]
report_timing_summary -file [file join $build_root main5a_ethernet_diag_place.timing]
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file [file join $build_root main5a_ethernet_diag_phy.ts]
report_timing_summary -file [file join $build_root main5a_ethernet_diag_final.timing]
report_timing_exception -file [file join $build_root main5a_ethernet_diag_exception.timing]
flow_status -file [file join $build_root main5a_ethernet_diag_pr.status]
export_db [file join $build_root main5a_ethernet_diag_pr.db]
exit
