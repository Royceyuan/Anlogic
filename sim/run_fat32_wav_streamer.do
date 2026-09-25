vlib work_wav
vmap work work_wav
vlog +define+SIM -work work_wav ../src/audio/fat32_wav_streamer.v tb_fat32_wav_streamer.v
vsim -c -lib work_wav tb_fat32_wav_streamer -do "run -all; quit -f"
