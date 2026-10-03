# Restore accepted datapaths and qualify startup with PLL lock; separate output.
set fd [open ./scripts/build_museum_main_board.tcl r]
set commands [read $fd]
close $fd
eval [string map {./_build_museum_main_board ./_build_flash_startup_repair} $commands]
