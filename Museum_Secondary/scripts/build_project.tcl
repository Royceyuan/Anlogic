import_device eagle_s20.db -package EG4S20BG256
set folder _build_secondary
file mkdir $folder
open_project museum_secondary_final.al -single_run
load_run_param -run syn_1
elaborate -top top_secondary_offline_av
read_adc constraints/secondary_offline_av.adc
clear_sdc -user
read_sdc constraints/secondary_offline_av.sdc
optimize_rtl
optimize_gate -packarea [file join $folder gate.area]
legalize_phy_inst
update_timing
report_area -io_info -file [file join $folder resources.area]
report_timing_summary -file [file join $folder pre_route.timing]
export_db [file join $folder gate.db]
puts "PASS MUSEUM_SECONDARY_GATE; not a bit or board result"
if {[info exists ::env(OFFLINE_AV_ROUTE)] && $::env(OFFLINE_AV_ROUTE)==1} {
    source seed/formal/build_config.tcl
    set seed $formal_place_seed
    if {[info exists ::env(OFFLINE_AV_SEED)]} {set seed $::env(OFFLINE_AV_SEED)}
    set_param place seed $seed
    set_param place effort high
    set_param place opt_timing high
    set_param place logic_level_opt on
    place
    set_param route fix_hold off
    set_param route effort routability
    route
    fix_hold
    set_param route fix_hold on
    update_timing -mode final
    drc_check -all
    report_area -io_info -file [file join $folder final.area]
    report_timing_summary -file [file join $folder final.timing]
    report_timing_status -file [file join $folder final.ts]
    flow_status -file [file join $folder final.status]
    export_db [file join $folder final.db]
    puts "MUSEUM_SECONDARY_ROUTE_FINISHED; timing and regression gates still required"
}
exit
