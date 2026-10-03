onerror {quit -code 1 -f}
set fd [open run_remote_controls.do r]
set commands [read $fd]
close $fd
set stop [string first {if {![info exists local_manual_test]}} $commands]
if {$stop<0} {error "Remote fixture compile boundary changed"}
eval [string range $commands 0 [expr {$stop-1}]]
vsim -novopt -onfinish stop -lib work_main5_remote tb_museum_media_core -gMAIN5_REMOTE_TEST=1 -gSOURCE_DIMENSIONS_TEST=1
run -all
if {[examine -radix unsigned sim:/tb_museum_media_core/source_dimensions_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
