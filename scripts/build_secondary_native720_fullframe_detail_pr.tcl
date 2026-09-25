import_device eagle_s20.db -package EG4S20BG256
set secondary_root .
set secondary_build [file join $secondary_root _build_secondary_native720_fullframe_detail]
file mkdir $secondary_build
cd $secondary_root
open_project [file join $secondary_root hx4s20_secondary_native720_fullframe_detail.al] -single_run
load_run_param -run syn_1
elaborate -top top_1280x720_sdram_fullframe_detail
read_adc [file join $secondary_root constraints top_1280x720_secondary_local.adc]
clear_sdc -user
read_sdc [file join $secondary_root constraints top_1280x720_sdram_fullframe_detail.sdc]
optimize_rtl
report_area -file [file join $secondary_build secondary_native720_fullframe_detail_rtl.area]
optimize_gate -packarea [file join $secondary_build secondary_native720_fullframe_detail_gate.area]
legalize_phy_inst
update_timing
report_timing_status -file [file join $secondary_build secondary_native720_fullframe_detail_gate.ts]
report_timing_summary -file [file join $secondary_build secondary_native720_fullframe_detail_gate.timing]
flow_status -file [file join $secondary_build secondary_native720_fullframe_detail_syn.status]
export_db [file join $secondary_build secondary_native720_fullframe_detail_gate.db]

set_param place seed 1
place
update_timing -mode manhattan
report_area -io_info -file [file join $secondary_build secondary_native720_fullframe_detail_place.area]
report_timing_summary -file [file join $secondary_build secondary_native720_fullframe_detail_place.timing]
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file [file join $secondary_build secondary_native720_fullframe_detail_final.ts]
report_timing_summary -file [file join $secondary_build secondary_native720_fullframe_detail_final.timing]
report_timing_exception -file [file join $secondary_build secondary_native720_fullframe_detail_exception.timing]
flow_status -file [file join $secondary_build secondary_native720_fullframe_detail_pr.status]
export_db [file join $secondary_build secondary_native720_fullframe_detail_pr.db]
exit
