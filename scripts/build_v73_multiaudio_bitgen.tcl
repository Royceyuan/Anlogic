# Generate the multi-track candidate from the completed v73 place-and-route DB.
set root [file normalize [pwd]]
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $root _build_v73_audio_visualizer v73_audio_visualizer_pr.db]
bitgen -bit [file join $root release hx4s20_1280x720_v73_multiaudio.bit]
exit
