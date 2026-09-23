import_device eagle_s20.db -package EG4S20BG256
set build_project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $build_project_root _build_main3_interaction]
set build_project_file [file join $build_project_root hx4s20_800x600_multimedia.al]
set build_sdc_file [file join $build_project_root constraints top_1280x720_main3_interaction.sdc]
set build_adc_file [file join $build_project_root constraints top_1280x720_v73_audio_visualizer.adc]
set build_top_module top_1280x720_main3_interaction

file mkdir $build_root
cd $build_project_root
open_project $build_project_file -single_run
load_run_param -run syn_1
elaborate -top $build_top_module
read_adc $build_adc_file
clear_sdc -user
read_sdc $build_sdc_file
optimize_rtl
report_area -file $build_root/main3_interaction_rtl.area
optimize_gate -packarea $build_root/main3_interaction_gate.area
legalize_phy_inst
update_timing
report_timing_status -file $build_root/main3_interaction_gate.ts
report_timing_summary -file $build_root/main3_interaction_gate.timing
flow_status -file $build_root/main3_interaction_syn.status
export_db $build_root/main3_interaction_gate.db

set_param place seed 76
place
update_timing -mode manhattan
report_area -io_info -file $build_root/main3_interaction_place.area
report_timing_summary -file $build_root/main3_interaction_place.timing
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file $build_root/main3_interaction_phy.ts
report_timing_summary -file $build_root/main3_interaction_final.timing
report_timing_exception -file $build_root/main3_interaction_exception.timing
flow_status -file $build_root/main3_interaction_pr.status
export_db $build_root/main3_interaction_pr.db
exit
