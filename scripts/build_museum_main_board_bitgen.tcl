import_device eagle_s20.db -package EG4S20BG256
import_db ./_build_museum_main_board/museum_main_board_pr.db -check_drc
drc_check -all -verbose
report_route_status -drc
set timing_fd [open ./_build_museum_main_board/museum_main_board_final.ts r]
set timing_status [read $timing_fd]
close $timing_fd
if {[regexp {SWNS: ([0-9.]+)ns, STNS: 0.000ns\.\s+HWNS: ([0-9.]+)ns, HTNS: 0.000ns\.} $timing_status]} {bitgen -bit ./release/dual_fpga_museum_terminal_main_board.bit} else {error "Main-board setup/hold not closed; refusing bitgen"}
exit
