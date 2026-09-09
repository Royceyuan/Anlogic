set build_project_root [file normalize [pwd]]
set build_root [file join $build_project_root _build_v73_phase2_detail]
set build_bit_file [file join $build_project_root release hx4s20_1280x720_v73_phase2_detail.bit]

cd $build_project_root
import_device eagle_s20.db -package EG4S20BG256
import_db $build_root/v73_phase2_detail_pr.db
bitgen -bit $build_bit_file
exit
