# Run only after MAIN-1 P&R has non-negative setup/hold WNS and zero TNS.
set build_project_root [file normalize [file join [file dirname [info script]] ..]]
set build_root [file join $build_project_root _build_main1_overview]
set build_bit_file [file join $build_project_root release hx4s20_main1_overview.bit]

cd $build_project_root
import_device eagle_s20.db -package EG4S20BG256
import_db $build_root/main1_overview_pr.db
bitgen -bit $build_bit_file
exit
