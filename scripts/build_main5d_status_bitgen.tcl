import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
cd $project_root
import_db [file join $project_root _build_main5d_status main5d_pr.db] -check_drc
drc_check -all -verbose
report_route_status -drc
set timing_fd [open [file join $project_root _build_main5d_status main5d_final.ts] r]
set timing_status [read $timing_fd]
close $timing_fd
if {[regexp {SWNS: ([0-9.]+)ns, STNS: 0.000ns\.\s+HWNS: ([0-9.]+)ns, HTNS: 0.000ns\.} $timing_status]} {bitgen -bit [file join $project_root release hx4s20_main5d_status.bit]} else {error "MAIN-5D repair setup/hold not closed; refusing bitgen"}
exit
