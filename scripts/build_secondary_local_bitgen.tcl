import_device eagle_s20.db -package EG4S20BG256
set secondary_root [file dirname [file dirname [file normalize [info script]]]]
set secondary_build [file join $secondary_root _build_secondary_local]
set secondary_db [file join $secondary_build secondary_local_pr.db]
set secondary_status [file join $secondary_build secondary_local_pr.status]
set secondary_console [file join $secondary_build secondary_local_pr.console.log]
if {![file exists $secondary_db]} { puts "REFUSED: missing P&R database"; exit }
if {![file exists $secondary_status]} { puts "REFUSED: missing P&R status"; exit }
if {![file exists $secondary_console]} { puts "REFUSED: missing P&R console log"; exit }
set status_file [open $secondary_status r]
set status_text [read $status_file]
close $status_file
set console_file [open $secondary_console r]
set console_text [read $console_file]
close $console_file
set setup_ok [regexp {Setup[[:space:]]+:[[:space:]]+WNS[[:space:]]+(-?[0-9]+)ps[[:space:]]+TNS[[:space:]]+(-?[0-9]+)ps[[:space:]]+NUM_FEPS[[:space:]]+([0-9]+)} $status_text match setup_wns setup_tns setup_feps]
set hold_ok [regexp {Hold[[:space:]]+:[[:space:]]+WNS[[:space:]]+(-?[0-9]+)ps[[:space:]]+TNS[[:space:]]+(-?[0-9]+)ps[[:space:]]+NUM_FEPS[[:space:]]+([0-9]+)} $status_text match hold_wns hold_tns hold_feps]
set log_ok [expr {![regexp { ERROR:|black box} $console_text] && [string first {Top Model        : top_1280x720_secondary_local} $status_text] >= 0 && [string first {No multi-drive.} $console_text] >= 0 && [string first {No abnormal timing path.} $console_text] >= 0}]
foreach log_line [split $console_text "\n"] {if {[string first {CRITICAL-WARNING:} $log_line] >= 0 && ![regexp {^PHY-(7002|5079) CRITICAL-WARNING:} [string trim $log_line]]} {set log_ok 0}}
set timing_ok [expr {$setup_ok && $hold_ok && $log_ok && $setup_wns >= 0 && $setup_tns == 0 && $setup_feps == 0 && $hold_wns >= 0 && $hold_tns == 0 && $hold_feps == 0}]
cd $secondary_root
if {$timing_ok} {import_db $secondary_db; bitgen -bit [file join $secondary_root release hx4s20_secondary_local.bit]} else {puts "REFUSED: P&R errors or failed timing"}
exit
