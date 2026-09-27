import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5d_resource]
cd $project_root
import_db [file join $build_root main5d_gate.db]
legalize_phy_inst
set_param place seed 1
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
place
update_timing -mode manhattan
report_area -io_info -file [file join $build_root main5d_reference_place.area]
report_qor -step place -file [file join $build_root main5d_reference_place.qor]
report_timing_summary -file [file join $build_root main5d_reference_place.timing]
flow_status -file [file join $build_root main5d_reference_place.status]
export_db [file join $build_root main5d_reference_place.db]
exit
