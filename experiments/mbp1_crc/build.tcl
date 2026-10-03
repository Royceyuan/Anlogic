# Fixed seed, same pins/clocks; use only the generated CRC variant.
set root [file normalize .]
source ./experiments/mbp1_crc/prepare.tcl
set fd [open ./dual_fpga_museum_terminal_main_board.al r]
set project [read $fd]
close $fd
set fd [open $out/dual_fpga_museum_terminal_main_board.al w]
set project [string map {src/ethernet/mbp1_codec.v _build_mbp1_crc_candidate/mbp1_codec_folded.v} $project]
set project [string map [list "Path=\"$root\"" "Path=\"$out\""] $project]
puts -nonewline $fd [string map {{<File Path="} {<File Path="../}} $project]
close $fd
set fd [open ./scripts/build_museum_main_board.tcl r]
set commands [read $fd]
close $fd
set include_file vendor/anlogic_lab6/sdram/enc_file/global_def.v
file mkdir $out/[file dirname $include_file]
file copy -force $include_file $out/$include_file
cd $out
eval [string map {
    ./_build_museum_main_board .
    ./constraints/ ../constraints/
} $commands]
