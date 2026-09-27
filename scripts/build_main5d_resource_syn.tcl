import_device eagle_s20.db -package EG4S20BG256
set project_root [file dirname [file dirname [file normalize [info script]]]]
set build_root [file join $project_root _build_main5d_resource]
file mkdir $build_root
cd $project_root
open_project [file join $project_root hx4s20_museum_terminal.al] -single_run
load_run_param -run syn_1
elaborate -top top_main5d_control
read_adc [file join $project_root constraints top_main5d_control.adc]
clear_sdc -user
read_sdc [file join $project_root constraints top_main5d_control.sdc]
optimize_rtl
set_param gate pack_effort high
optimize_gate -packarea [file join $build_root main5d_gate.area]
export_db [file join $build_root main5d_gate.db]
exit
