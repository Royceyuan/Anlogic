set fd [open ./scripts/build_museum_main_board_bitgen.tcl r]
set commands [read $fd]
close $fd
eval [string map {
    ./_build_museum_main_board ./_build_flash_startup_repair
    ./release/dual_fpga_museum_terminal_main_board.bit ./release/dual_fpga_museum_terminal_main_board_hdmi_b.bit
} $commands]
