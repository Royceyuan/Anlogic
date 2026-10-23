import_device eagle_s20.db -package EG4S20BG256
set folder _build_main
import_db [file join $folder gate.db]
set_param place seed 5
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
puts "MUSEUM_MAIN_ROUTE_FINISHED"
exit
