import_device eagle_s20.db -package EG4S20BG256
set root .
set build [file join $root _build_secondary_main5e]
set status [file join $build secondary_main5e_pr.status]
set log [file join $build console.log]
set db [file join $build secondary_main5e_pr.db]
if {![file exists $status] || ![file exists $log] || ![file exists $db]} {puts "REFUSED: missing P&R evidence"; exit}
set f [open $status r]; set s [read $f]; close $f
set f [open $log r]; set l [read $f]; close $f
set good [expr {[string first {Top Model        : top_secondary_main5e} $s] >= 0 && [regexp {Setup[[:space:]]+:[[:space:]]+WNS[[:space:]]+([0-9]+)ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $s] && [regexp {Hold[[:space:]]+:[[:space:]]+WNS[[:space:]]+([0-9]+)ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $s] && [string first {No multi-drive.} $l] >= 0 && [string first {No abnormal timing path.} $l] >= 0 && ![regexp { ERROR:|black box|No clock match|Clock group is empty} $l]}]
foreach line [split $l "\n"] {if {[string first {CRITICAL-WARNING:} $line] >= 0 && ![regexp {^PHY-(7002|5079) CRITICAL-WARNING:} [string trim $line]]} {set good 0}}
foreach file {hx4s20_secondary_main5e.al constraints/top_secondary_main5e.adc constraints/top_secondary_main5e.sdc src/storage/bmp_row_buffer.v src/memory/sdram_bmp_row_top_v66.v src/secondary/secondary_carousel_controller.v src/secondary/top_secondary_main5e.v src/secondary/top_secondary_main5e_netdiag.v src/secondary/secondary_main5e_keys.v src/secondary/secondary_main5e_status_adapter.v src/secondary/secondary_main5e_engineering_overlay.v src/ethernet/mbp1_fixed_udp.v src/ethernet/mbp1_codec.v src/ethernet/mbp1_secondary_endpoint.v} {if {![file exists [file join $root $file]] || [file mtime [file join $root $file]] > [file mtime $db]} {set good 0}}
if {!$good} {puts "REFUSED: stale P&R, warnings, or failed timing"; exit}
cd $root
import_db $db
bitgen -bit [file join $root release hx4s20_secondary_main5e_carousel_fix_v02.bit]
exit
