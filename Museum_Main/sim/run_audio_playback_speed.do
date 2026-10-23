onerror {quit -code 1 -f}
if {[file exists work_audio_speed]} {vdel -lib work_audio_speed -all}
vlib work_audio_speed
vlog -work work_audio_speed ../src/audio/audio_pcm_player_48k.v tb_audio_playback_speed.v
vsim -novopt -onfinish stop -lib work_audio_speed tb_audio_playback_speed
run -all
if {[examine -radix unsigned /tb_audio_playback_speed/test_pass] != 1} {quit -code 1 -f}
quit -f
