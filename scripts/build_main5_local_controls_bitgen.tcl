import_device eagle_s20.db -package EG4S20BG256
set build_project_root [file normalize [pwd]]
set build_root [file join $build_project_root _build_main5_local_controls]
set build_bit_file [file join $build_project_root release hx4s20_main5_local_controls.bit]

cd $build_project_root
import_db $build_root/main5_local_controls_pr.db
bitgen -bit $build_bit_file
exit
