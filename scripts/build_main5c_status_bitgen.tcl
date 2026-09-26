import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
cd $project_root
import_db [file join $project_root _build_main5c_status main5c_pr.db]
bitgen -bit [file join $project_root release hx4s20_main5c_light_udp_trial.bit]
exit
