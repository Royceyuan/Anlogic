import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_museum_main_board]
file mkdir $build_root
cd $project_root
open_project [file join $project_root dual_fpga_museum_terminal_main_board.al] -single_run
load_run_param -run syn_1
elaborate -top dual_fpga_museum_terminal_main_board
read_adc [file join $project_root constraints museum_main_board_pins.adc]
clear_sdc -user
read_sdc [file join $project_root constraints museum_main_board_timing.sdc]
optimize_rtl
set_param gate pack_effort high
optimize_gate -packarea [file join $build_root museum_main_board_gate.area]
export_db [file join $build_root museum_main_board_gate.db]
legalize_phy_inst
set_param place seed 1
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
place
update_timing -mode manhattan
report_area -io_info -file [file join $build_root museum_main_board_place.area]
report_timing_summary -file [file join $build_root museum_main_board_place.timing]
export_db [file join $build_root museum_main_board_place.db]
set_param route fix_hold off
set_param route effort routability
route
fix_hold
set_param route fix_hold on
update_timing -mode final
drc_check -all
report_area -io_info -file [file join $build_root museum_main_board_final.area]
report_qor -step route -file [file join $build_root museum_main_board_final.qor]
report_timing_status -file [file join $build_root museum_main_board_final.ts]
report_timing_summary -file [file join $build_root museum_main_board_final.timing]
flow_status -file [file join $build_root museum_main_board_pr.status]
export_db [file join $build_root museum_main_board_pr.db]
exit
