import_device eagle_s20.db -package EG4S20BG256
set build_project_root [file normalize [pwd]]
set build_root [file join $build_project_root _build_main4_emergency]
set build_bit_file [file join $build_project_root release hx4s20_main4_emergency.bit]

cd $build_project_root
import_db $build_root/main4_emergency_pr.db
bitgen -bit $build_bit_file
exit
