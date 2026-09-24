if {[file exists work_audio_visualizer]} {vdel -lib work_audio_visualizer -all}
vlib work_audio_visualizer
vmap work work_audio_visualizer
vlog +define+SIM -work work_audio_visualizer ../src/storage/al_dp_ram32.v ../src/video/audio_visualizer_overlay.v tb_audio_visualizer_overlay.v
vsim -c -lib work_audio_visualizer tb_audio_visualizer_overlay
run -all
quit -f
