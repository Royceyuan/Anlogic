# MAIN-1 build: five cached thumbnails with frame-boundary selection.
set build_project_root [file normalize [file join [file dirname [info script]] ..]]
set build_root [file join $build_project_root _build_main1_overview]
set build_project_file [file join $build_project_root hx4s20_800x600_multimedia.al]
set build_sdc_file [file join $build_project_root constraints top_1280x720_v72_resource_optimized.sdc]
set build_adc_file [file join $build_project_root constraints top_800x600_adaptive_v66_uart_subtitle.adc]
set build_top_module top_1280x720_main1_overview

file mkdir $build_root
cd $build_project_root
puts "MAIN-1 overview project: $build_project_file"
import_device eagle_s20.db -package EG4S20BG256
open_project $build_project_file -single_run
load_run_param -run syn_1
elaborate -top $build_top_module
read_adc $build_adc_file
clear_sdc -user
read_sdc $build_sdc_file
optimize_rtl
report_area -file $build_root/main1_overview_rtl.area
optimize_gate -packarea $build_root/main1_overview_gate.area
legalize_phy_inst
update_timing
report_timing_status -file $build_root/main1_overview_gate.ts
report_timing_summary -file $build_root/main1_overview_gate.timing
flow_status -file $build_root/main1_overview_syn.status
export_db $build_root/main1_overview_gate.db

place
update_timing -mode manhattan
report_area -io_info -file $build_root/main1_overview_place.area
report_timing_summary -file $build_root/main1_overview_place.timing
route
fix_hold
update_timing -mode final
report_timing_status -file $build_root/main1_overview_phy.ts
report_timing_summary -file $build_root/main1_overview_final.timing
report_timing_exception -file $build_root/main1_overview_exception.timing
flow_status -file $build_root/main1_overview_pr.status
export_db $build_root/main1_overview_pr.db
exit
