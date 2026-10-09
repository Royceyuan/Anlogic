import_device eagle_s20.db -package EG4S20BG256
set secondary_root .
set project hx4s20_secondary_main5e.al
set top top_secondary_main5e
set sdc constraints/top_secondary_main5e.sdc
set adc constraints/top_secondary_main5e.adc
if {[info exists ::env(SECONDARY_PROJECT)]} {set project $::env(SECONDARY_PROJECT)}
if {[info exists ::env(SECONDARY_TOP)]} {set top $::env(SECONDARY_TOP)}
if {[info exists ::env(SECONDARY_SDC)]} {set sdc $::env(SECONDARY_SDC)}
if {[info exists ::env(SECONDARY_ADC)]} {set adc $::env(SECONDARY_ADC)}
set secondary_build [file join $secondary_root _build_secondary_help_fixed720_seed6]
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

set_param place seed 6
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
