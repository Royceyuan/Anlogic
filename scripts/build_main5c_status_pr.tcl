import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5c_status]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_museum_terminal.al] -single_run
load_run_param -run syn_1
elaborate -top top_main5c_status
read_adc [file join $project_root constraints top_main5d_control.adc]
clear_sdc -user
read_sdc [file join $project_root constraints top_main5d_control.sdc]
optimize_rtl
report_area -file [file join $build_root main5c_rtl.area]
optimize_gate -packarea [file join $build_root main5c_gate.area]
legalize_phy_inst
update_timing
report_timing_status -file [file join $build_root main5c_gate.ts]
report_timing_summary -file [file join $build_root main5c_gate.timing]
flow_status -file [file join $build_root main5c_syn.status]
export_db [file join $build_root main5c_gate.db]
set_param place seed 97
place
update_timing -mode manhattan
report_area -io_info -file [file join $build_root main5c_place.area]
report_timing_summary -file [file join $build_root main5c_place.timing]
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file [file join $build_root main5c_phy.ts]
report_timing_summary -file [file join $build_root main5c_final.timing]
report_timing_exception -file [file join $build_root main5c_exception.timing]
flow_status -file [file join $build_root main5c_pr.status]
export_db [file join $build_root main5c_pr.db]
exit
