onerror {quit -code 1 -f}
if {[file exists work_half_memory]} {vdel -lib work_half_memory -all}
vlib work_half_memory
vlog +define+SIM -work work_half_memory ../src/storage/al_dp_ram32.v ../src/video/linebuf_scaler_960x540_to_1280x720.v ../vendor/anlogic_lab6/frame_fifo_read.v ../vendor/anlogic_lab6/al_ip/afifo_32_16_256.v tb_half_zoom_memory.v
vsim -c -voptargs=+acc -onfinish stop -lib work_half_memory tb_half_zoom_memory
run -all
if {[examine -radix binary /tb_half_zoom_memory/passed] ne "1"} {quit -code 1 -f}
quit -f
