import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5d_timing]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_museum_terminal.al] -single_run
load_run_param -run syn_1
elaborate -top top_main5d_control
read_adc [file join $project_root constraints top_main5d_control.adc]
clear_sdc -user
read_sdc [file join $project_root constraints top_main5d_control.sdc]
optimize_rtl
set_param gate pack_effort high
optimize_gate -packarea [file join $build_root main5d_gate.area]
export_db [file join $build_root main5d_gate.db]
legalize_phy_inst
set_param place seed 1
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
place
update_timing -mode manhattan
report_area -io_info -file [file join $build_root main5d_place.area]
report_qor -step place -file [file join $build_root main5d_place.qor]
report_timing_summary -file [file join $build_root main5d_place.timing]
export_db [file join $build_root main5d_place.db]
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
drc_check -all
report_area -io_info -file [file join $build_root main5d_final.area]
report_qor -step route -file [file join $build_root main5d_final.qor]
report_timing_status -file [file join $build_root main5d_final.ts]
report_timing_summary -file [file join $build_root main5d_final.timing]
report_timing_exception -file [file join $build_root main5d_exception.timing]
flow_status -file [file join $build_root main5d_pr.status]
export_db [file join $build_root main5d_pr.db]
exit
