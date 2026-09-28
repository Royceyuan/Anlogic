import_device eagle_s20.db -package EG4S20BG256
set root [file dirname [file dirname [file normalize [info script]]]]
set build [file join $root _build_secondary_main5e_netdiag]
set status [file join $build secondary_main5e_netdiag_pr.status]
set log [file join $build console.log]
set db [file join $build secondary_main5e_netdiag_pr.db]
if {![file exists $status] || ![file exists $log] || ![file exists $db]} {puts "REFUSED: missing P&R evidence"; exit}
set f [open $status r]; set s [read $f]; close $f
set f [open $log r]; set l [read $f]; close $f
set good [expr {[string first {Top Model        : top_secondary_main5e_netdiag_board} $s] >= 0 && [regexp {Setup[[:space:]]+:[[:space:]]+WNS[[:space:]]+([0-9]+)ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $s] && [regexp {Hold[[:space:]]+:[[:space:]]+WNS[[:space:]]+([0-9]+)ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $s] && [string first {No multi-drive.} $l] >= 0 && [string first {No abnormal timing path.} $l] >= 0 && ![regexp { ERROR:|black box} $l]}]
foreach line [split $l "\n"] {if {[string first {CRITICAL-WARNING:} $line] >= 0 && ![regexp {^PHY-5079 CRITICAL-WARNING:} [string trim $line]]} {set good 0}}
if {!$good} {puts "REFUSED: P&R evidence or timing failed"; exit}
cd $root
import_db $db
bitgen -bit [file join $root release hx4s20_secondary_main5e_netdiag_v01.bit]
exit
