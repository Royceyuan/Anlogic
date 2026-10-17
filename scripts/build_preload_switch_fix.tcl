# Full seed-1 build plus the verified incremental hold repair.
set fd [open ./scripts/build_museum_main_board.tcl r]
set commands [read $fd]
close $fd
eval [string map [list \
    ./_build_museum_main_board ./_build_preload_switch_fix \
    {set_param place seed 4} {set_param place seed 1} \
    "\nexit" "\n# Continue with hold repair."] $commands]
import_db ./_build_preload_switch_fix/museum_main_board_pr.db -check_drc
set_param route fix_hold on
set_param route hold_fix_iteration 20
route -incremental
fix_hold
update_timing -mode final
drc_check -all
report_area -io_info -file ./_build_preload_switch_fix/museum_main_board_final.area
report_qor -step route -file ./_build_preload_switch_fix/museum_main_board_final.qor
report_timing_status -file ./_build_preload_switch_fix/museum_main_board_final.ts
report_timing_summary -file ./_build_preload_switch_fix/museum_main_board_final.timing
flow_status -file ./_build_preload_switch_fix/museum_main_board_pr.status
export_db ./_build_preload_switch_fix/museum_main_board_pr.db
exit
