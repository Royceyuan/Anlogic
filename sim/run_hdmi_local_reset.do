onerror {quit -code 1 -f}
if {[file exists work_hdmi_local_reset]} {vdel -lib work_hdmi_local_reset -all}
vlib work_hdmi_local_reset
set source [exec git show 78d2ac5:src/video/hdmi_audio_video_phy.v]
set source [string map {"module hdmi_audio_video_phy #(" "module hdmi_audio_video_phy_ref #("} $source]
set fd [open work_hdmi_local_reset/hdmi_audio_video_phy_ref.v w]
puts $fd $source
close $fd
vlog -work work_hdmi_local_reset ../src/common/reset_sync.v ../src/video/hdmi_tmds_lane_serializer.v ../src/video/hdmi_audio_video_phy.v work_hdmi_local_reset/hdmi_audio_video_phy_ref.v tb_hdmi_local_reset.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_local_reset tb_hdmi_local_reset
run -all
if {[examine -radix binary /tb_hdmi_local_reset/test_pass] ne "1"} {quit -code 1 -f}
quit -f
