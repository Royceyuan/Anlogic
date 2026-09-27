import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5d_resource]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_museum_terminal.al] -single_run
load_run_param -run syn_1
if {[info exists env(MBP1_RESOURCE_REF)]} {set source [exec git show $env(MBP1_RESOURCE_REF):src/ethernet/mbp1_main_endpoint.v]} else {set fd [open src/ethernet/mbp1_main_endpoint.v r]; set source [read $fd]; close $fd}
set source [string map {"module mbp1_main_endpoint #(" "module mbp1_resource_endpoint #(" "ENABLE_CONTROL = 0" "ENABLE_CONTROL = 1" "ENABLE_PLAYBACK = 0" "ENABLE_PLAYBACK = 1" "HOLD_TX_FIELDS = 1" "HOLD_TX_FIELDS = 0"} $source]
set fd [open [file join $build_root mbp1_resource_endpoint.v] w]
puts $fd {`include "src/ethernet/mbp1_codec.v"}
puts $fd $source
close $fd
read_verilog -file [file join $build_root mbp1_resource_endpoint.v]
elaborate -top mbp1_resource_endpoint
clear_sdc -user
optimize_rtl
set_param gate pack_effort high
optimize_gate -packarea [file join $build_root mbp1_endpoint.area]
exit
