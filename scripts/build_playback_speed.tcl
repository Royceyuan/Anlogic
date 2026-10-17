# Isolated candidate; preserve the startup-read board-accepted release.
set fd [open ./scripts/build_museum_main_board.tcl r]
set commands [read $fd]
close $fd
eval [string map {./_build_museum_main_board ./_build_playback_speed_v2} $commands]
