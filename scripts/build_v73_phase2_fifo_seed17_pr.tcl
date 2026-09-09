set build_project_root [file normalize [pwd]]
set source_root [file join $build_project_root _build_v73_phase2_fifo_response]
set build_root [file join $build_project_root _build_v73_phase2_fifo_seed17]
file mkdir $build_root
cd $build_project_root
import_device eagle_s20.db -package EG4S20BG256
import_db $source_root/v73_phase2_fifo_response_gate.db
set_param place seed 17
place
update_timing -mode manhattan
report_timing_summary -file $build_root/v73_phase2_fifo_seed17_place.timing
route
fix_hold
update_timing -mode final
report_timing_status -file $build_root/v73_phase2_fifo_seed17_phy.ts
report_timing_summary -file $build_root/v73_phase2_fifo_seed17_final.timing
flow_status -file $build_root/v73_phase2_fifo_seed17_pr.status
export_db $build_root/v73_phase2_fifo_seed17_pr.db
exit
