import_device eagle_s20.db -package EG4S20BG256
file mkdir ./_build_museum_main_board
open_project ./dual_fpga_museum_terminal_main_board.al -single_run
load_run_param -run syn_1
elaborate -top dual_fpga_museum_terminal_main_board
read_adc ./constraints/museum_main_board_pins.adc
clear_sdc -user
read_sdc ./constraints/museum_main_board_timing.sdc
optimize_rtl
set_param gate pack_effort high
optimize_gate -packarea ./_build_museum_main_board/museum_main_board_gate.area
export_db ./_build_museum_main_board/museum_main_board_gate.db
legalize_phy_inst
set_param place seed 1
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
place
update_timing -mode manhattan
report_area -io_info -file ./_build_museum_main_board/museum_main_board_place.area
report_timing_summary -file ./_build_museum_main_board/museum_main_board_place.timing
export_db ./_build_museum_main_board/museum_main_board_place.db
set_param route fix_hold off
set_param route effort routability
route
fix_hold
set_param route fix_hold on
update_timing -mode final
drc_check -all
report_area -io_info -file ./_build_museum_main_board/museum_main_board_final.area
report_qor -step route -file ./_build_museum_main_board/museum_main_board_final.qor
report_timing_status -file ./_build_museum_main_board/museum_main_board_final.ts
report_timing_summary -file ./_build_museum_main_board/museum_main_board_final.timing
flow_status -file ./_build_museum_main_board/museum_main_board_pr.status
export_db ./_build_museum_main_board/museum_main_board_pr.db
exit
