# Reuse only the gate.db belonging to the captured build_sources.json.
import_device eagle_s20.db -package EG4S20BG256
set folder _build_secondary
import_db [file join $folder gate.db]
source seed/formal/build_config.tcl
set seed $formal_place_seed
if {[info exists ::env(OFFLINE_AV_SEED)]} {set seed $::env(OFFLINE_AV_SEED)}
set_param place seed $seed
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
set_param place aggressive_opt 21
set_param place aggr_neighbor_dist 5
set_param place enhanced_beeline_opt 3
set_param place timing_driven_mode on
set_param place shifter_opt on
set_param place crit_path_opt on
set_param place post_place_opt high
set_param place hfn_opt_effort high
set_param place split_data_from_clock on
set_param route post_route_opt high
set_param route postrt_opt_extra_round 4
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
puts "MUSEUM_SECONDARY_ROUTE_FINISHED; seed$seed; timing and regression gates still required"
exit
