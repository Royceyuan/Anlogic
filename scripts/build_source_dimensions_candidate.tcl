# Same product, pins, clocks and seed; never overwrite accepted build/bit.
set fd [open ./scripts/build_museum_main_board.tcl r]
set commands [read $fd]
close $fd
eval [string map {./_build_museum_main_board ./_build_source_dimensions} $commands]
