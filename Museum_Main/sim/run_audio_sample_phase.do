onerror {quit -code 1 -f}
if {[file exists work_audio_phase]} {vdel -lib work_audio_phase -all}
vlib work_audio_phase
vlog -work work_audio_phase ../src/audio/audio_pcm_player_48k.v ../src/video/museum_emergency_overlay.v tb_audio_sample_phase.v
vsim -novopt -c -onfinish stop -lib work_audio_phase tb_audio_sample_phase
run -all
if {[examine -radix unsigned sim:/tb_audio_sample_phase/test_pass]!=1} {quit -code 1 -f}
quit -code 0 -f
