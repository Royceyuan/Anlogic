import_device eagle_s20.db -package EG4S20BG256
set project_root [file normalize [pwd]]
set build_root [file join $project_root _build_main5a_ethernet_diag]
cd $project_root
import_db [file join $project_root _build_main5a_ethernet_diag main5a_ethernet_diag_pr.db]
bitgen -bit [file join $project_root release hx4s20_main5a_ethernet_diag.bit]
exit
