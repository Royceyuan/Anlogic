set f [open ./scripts/build_museum_main_board_bitgen.tcl r]
set commands [read $f]
close $f
if {[file exists ./release/dual_fpga_museum_terminal_main_board_startup_read_fix.bit]} {
    error "Candidate already exists; refusing overwrite"
}
eval [string map {
    ./_build_museum_main_board ./_build_flash_startup_repair
    ./release/dual_fpga_museum_terminal_main_board.bit ./release/dual_fpga_museum_terminal_main_board_startup_read_fix.bit
} $commands]
