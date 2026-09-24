# Full Phase 2 P&R from the accepted Phase 1 source baseline.
set build_project_root [file normalize [pwd]]
set build_root [file join $build_project_root _build_v73_phase2_detail]
set build_project_file [file join $build_project_root hx4s20_museum_terminal.al]
set build_sdc_file [file join $build_project_root constraints top_1280x720_v73_audio_visualizer.sdc]
set build_adc_file [file join $build_project_root constraints hx4s20_main_board.adc]
set build_top_module top_1280x720_feature_v73_audio_visualizer

file mkdir $build_root
cd $build_project_root
import_device eagle_s20.db -package EG4S20BG256
open_project $build_project_file -single_run
load_run_param -run syn_1
elaborate -top $build_top_module
read_adc $build_adc_file
clear_sdc -user
read_sdc $build_sdc_file
optimize_rtl
report_area -file $build_root/v73_phase2_detail_rtl.area
optimize_gate -packarea $build_root/v73_phase2_detail_gate.area
legalize_phy_inst
update_timing
report_timing_status -file $build_root/v73_phase2_detail_gate.ts
report_timing_summary -file $build_root/v73_phase2_detail_gate.timing
flow_status -file $build_root/v73_phase2_detail_syn.status
export_db $build_root/v73_phase2_detail_gate.db
set_param place seed 75
place
update_timing -mode manhattan
report_area -io_info -file $build_root/v73_phase2_detail_place.area
report_timing_summary -file $build_root/v73_phase2_detail_place.timing
route
fix_hold
update_timing -mode final
report_timing_status -file $build_root/v73_phase2_detail_phy.ts
report_timing_summary -file $build_root/v73_phase2_detail_final.timing
report_timing_exception -file $build_root/v73_phase2_detail_exception.timing
flow_status -file $build_root/v73_phase2_detail_pr.status
export_db $build_root/v73_phase2_detail_pr.db
exit
