import_device eagle_s20.db -package EG4S20BG256
set folder _build_tf_video
set fps 30
if {[info exists ::env(TF_VIDEO_FPS)]} {set fps $::env(TF_VIDEO_FPS)}
if {$fps!=30} {error "Only 30fps is active; the 40fps experiment is archived in workspace rubbish"}
set project secondary_tf_video.al
set height 360
if {[info exists ::env(TF_VIDEO_HEIGHT)]} {set height $::env(TF_VIDEO_HEIGHT)}
if {$height ni {360 480}} {error "Unsupported TF_VIDEO_HEIGHT"}
if {$height==480} {set folder _build_tf_video_480p;set project secondary_tf_video_480p.al}
file mkdir $folder
open_project $project -single_run
load_run_param -run syn_1
puts "TF_VIDEO_FPS=$fps"
puts "TF_VIDEO_HEIGHT=$height"
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
