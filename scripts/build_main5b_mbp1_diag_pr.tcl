import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5b_mbp1_diag]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_main5a_ethernet_diag.al] -single_run
load_run_param -run syn_1
elaborate -top top_main5b_mbp1_diag
read_adc [file join $project_root constraints top_main5a_ethernet_diag.adc]
clear_sdc -user
read_sdc [file join $project_root constraints top_main5b_mbp1_diag.sdc]
optimize_rtl
report_area -file [file join $build_root main5b_rtl.area]
optimize_gate -packarea [file join $build_root main5b_gate.area]
legalize_phy_inst
update_timing
report_timing_status -file [file join $build_root main5b_gate.ts]
report_timing_summary -file [file join $build_root main5b_gate.timing]
flow_status -file [file join $build_root main5b_syn.status]
export_db [file join $build_root main5b_gate.db]
set_param place seed 17
place
update_timing -mode manhattan
report_area -io_info -file [file join $build_root main5b_place.area]
report_timing_summary -file [file join $build_root main5b_place.timing]
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file [file join $build_root main5b_phy.ts]
report_timing_summary -file [file join $build_root main5b_final.timing]
report_timing_exception -file [file join $build_root main5b_exception.timing]
flow_status -file [file join $build_root main5b_pr.status]
export_db [file join $build_root main5b_pr.db]
exit
