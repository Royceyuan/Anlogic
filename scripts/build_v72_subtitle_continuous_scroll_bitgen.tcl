# Run only after the companion P&R report has non-negative setup/hold WNS.
set build_project_root [file normalize [file join [file dirname [info script]] ..]]
set build_root [file join $build_project_root _build_v72_subtitle_continuous_scroll]
set build_bit_file [file join $build_project_root release hx4s20_1280x720_v72_subtitle_continuous_scroll_v2.bit]

cd $build_project_root
import_device eagle_s20.db -package EG4S20BG256
import_db $build_root/subtitle_continuous_scroll_pr.db
bitgen -bit $build_bit_file
exit
