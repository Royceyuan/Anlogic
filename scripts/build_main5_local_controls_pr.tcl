import_device eagle_s20.db -package EG4S20BG256
set build_project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $build_project_root _build_main5_local_controls]
set build_project_file [file join $build_project_root hx4s20_museum_terminal.al]
set build_sdc_file [file join $build_project_root constraints top_1280x720_main5_local_controls.sdc]
set build_adc_file [file join $build_project_root constraints hx4s20_main_board.adc]
set build_top_module top_1280x720_main5_local_controls

file mkdir $build_root
cd $build_project_root
open_project $build_project_file -single_run
load_run_param -run syn_1
elaborate -top $build_top_module
read_adc $build_adc_file
clear_sdc -user
read_sdc $build_sdc_file
optimize_rtl
report_area -file $build_root/main5_local_controls_rtl.area
optimize_gate -packarea $build_root/main5_local_controls_gate.area
legalize_phy_inst
update_timing
report_timing_status -file $build_root/main5_local_controls_gate.ts
report_timing_summary -file $build_root/main5_local_controls_gate.timing
flow_status -file $build_root/main5_local_controls_syn.status
export_db $build_root/main5_local_controls_gate.db

set_param place seed 76
place
update_timing -mode manhattan
report_area -io_info -file $build_root/main5_local_controls_place.area
report_timing_summary -file $build_root/main5_local_controls_place.timing
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file $build_root/main5_local_controls_phy.ts
report_timing_summary -file $build_root/main5_local_controls_final.timing
report_timing_exception -file $build_root/main5_local_controls_exception.timing
flow_status -file $build_root/main5_local_controls_pr.status
export_db $build_root/main5_local_controls_pr.db
exit
