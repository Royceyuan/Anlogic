set fd [open ./scripts/build_museum_main_board_bitgen.tcl r]
set commands [read $fd]
close $fd
eval [string map {
    ./_build_museum_main_board ./_build_preload_switch_fix
    ./release/dual_fpga_museum_terminal_main_board.bit ./release/dual_fpga_museum_terminal_main_board_preload_switch_fix.bit
} $commands]
