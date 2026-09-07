# See the place-and-route script: TD command mode runs sourced batches with no
# usable [info script], so the repository root is the invocation directory.
set build_project_root [file normalize [pwd]]
set build_root [file join $build_project_root _build_v73_audio_visualizer]
set build_bit_file [file join $build_project_root release hx4s20_1280x720_v73_audio_visualizer.bit]
cd $build_project_root
import_device eagle_s20.db -package EG4S20BG256
import_db $build_root/v73_audio_visualizer_pr.db
bitgen -bit $build_bit_file
exit
