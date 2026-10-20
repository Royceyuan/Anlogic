import_device eagle_s20.db -package EG4S20BG256
set folder _build_tf_video
file mkdir $folder
open_project secondary_tf_video.al -single_run
load_run_param -run syn_1
elaborate -top top_secondary_tf_video
read_adc constraints/secondary_tf_video.adc
clear_sdc -user
read_sdc constraints/secondary_tf_video.sdc
optimize_rtl
optimize_gate -packarea [file join $folder gate.area]
legalize_phy_inst
update_timing
foreach clock {clk_50m sd_fast u_pll.clkc[0] u_pll.clkc[1] u_video_pll.clkc[0] u_video_pll.clkc[1]} {
    if {[llength [get_clocks $clock]]!=1} {error "Missing clock: $clock"}
}
report_area -file [file join $folder gate_resources.area]
set_param place seed 8
place
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_area -io_info -file [file join $folder final.area]
report_timing_summary -file [file join $folder final.timing]
report_timing_status -file [file join $folder final.ts]
flow_status -file [file join $folder final.status]
export_db [file join $folder final.db]
exit
