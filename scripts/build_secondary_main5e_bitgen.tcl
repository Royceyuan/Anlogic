import_device eagle_s20.db -package EG4S20BG256
set root .
set build [file join $root _build_secondary_main5e_manual_browse_seed6]
if {[info exists ::env(SECONDARY_BUILD)]} {set build $::env(SECONDARY_BUILD)}
set status [file join $build secondary_main5e_pr.status]
set log [file join $build console.log]
set db [file join $build secondary_main5e_pr.db]
if {![file exists $status] || ![file exists $log] || ![file exists $db]} {puts "REFUSED: missing P&R evidence"; exit}
set f [open $status r]; set s [read $f]; close $f
set f [open $log r]; set l [read $f]; close $f
set good [expr {[string first {Top Model        : top_secondary_main5e} $s] >= 0 && [regexp {Setup[[:space:]]+:[[:space:]]+WNS[[:space:]]+([0-9]+)ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $s] && [regexp {Hold[[:space:]]+:[[:space:]]+WNS[[:space:]]+([0-9]+)ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $s] && [string first {No multi-drive.} $l] >= 0 && [string first {No abnormal timing path.} $l] >= 0 && ![regexp { ERROR:|black box|No clock match|Clock group is empty} $l]}]
foreach line [split $l "\n"] {if {[string first {CRITICAL-WARNING:} $line] >= 0 && ![regexp {^PHY-(7002|5079) CRITICAL-WARNING:} [string trim $line]]} {set good 0}}
set f [open [file join $root hx4s20_secondary_main5e.al] r]; set project [read $f]; close $f
set required_files {hx4s20_secondary_main5e.al vendor/anlogic_lab6/sdram/enc_file/global_def.v vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/TEMAC_CORE_gate.v}
foreach {entry path} [regexp -all -inline {<File Path="([^"]+)"} $project] {lappend required_files $path}
lappend required_files src/secondary/secondary_help_font.vh
foreach file $required_files {if {![file exists [file join $root $file]] || [file mtime [file join $root $file]] > [file mtime $db]} {set good 0}}
if {!$good} {puts "REFUSED: stale P&R, warnings, or failed timing"; exit}
cd $root
import_db $db
set bit [file join $root release hx4s20_secondary_help.bit]
if {[info exists ::env(SECONDARY_BIT)]} {set bit $::env(SECONDARY_BIT)}
bitgen -bit $bit
exit
