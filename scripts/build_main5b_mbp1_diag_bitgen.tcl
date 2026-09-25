import_device eagle_s20.db -package EG4S20BG256
set project_root [file normalize [pwd]]
cd $project_root
import_db [file join $project_root _build_main5b_mbp1_diag main5b_pr.db]
bitgen -bit [file join $project_root release hx4s20_main5b_mbp1_diag.bit]
exit
