onerror {quit -code 1 -f}
vlib work_audio_equivalence
quietly set source [exec git show eb9c1aa:src/video/audio_visualizer_overlay.v]
quietly set source [string map {audio_visualizer_overlay audio_visualizer_overlay_ref audio_bar_ram audio_bar_ram_ref} $source]
quietly set fd [open work_audio_equivalence/reference.v w]
puts $fd $source
close $fd
vlog +define+SIM -work work_audio_equivalence ../src/video/audio_visualizer_overlay.v work_audio_equivalence/reference.v tb_audio_visualizer_equivalence.v
vsim -c -voptargs=+acc -onfinish stop -lib work_audio_equivalence tb_audio_visualizer_equivalence
run -all
if {[examine -radix unsigned /tb_audio_visualizer_equivalence/test_pass] != 1} {quit -code 1 -f}
quit -sim
# Check the non-SIM hardware wrapper too, not just an unchanged behavioral RAM.
vlib work_audio_equivalence_physical
vlog -work work_audio_equivalence_physical D:/TD_6.2.1/sim_release/eg4/eg_phy_bram.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram32k.v D:/TD_6.2.1/sim_release/eg4/eg_logic_bram.v
vlog -work work_audio_equivalence_physical ../src/video/audio_visualizer_overlay.v work_audio_equivalence/reference.v tb_audio_visualizer_equivalence.v
vsim -c -voptargs=+acc -onfinish stop -lib work_audio_equivalence_physical tb_audio_visualizer_equivalence
run -all
if {[examine -radix unsigned /tb_audio_visualizer_equivalence/test_pass] != 1} {quit -code 1 -f}
quit -f
