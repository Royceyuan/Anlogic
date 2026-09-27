onerror {quit -code 1 -f}
if {[file exists work_main5_pan_stream]} {vdel -lib work_main5_pan_stream -all}
vlib work_main5_pan_stream
vlog +define+SIM -work work_main5_pan_stream ../src/storage/al_dp_ram32.v ../src/video/linebuf_scaler_960x540_to_1280x720.v tb_linebuf_scaler_zoom_stream.v
vsim -c -voptargs=+acc -onfinish stop -lib work_main5_pan_stream tb_linebuf_scaler_zoom_stream
run -all
if {[examine -radix binary /tb_linebuf_scaler_zoom_stream/test_pass] ne "1"} {quit -code 1 -f}
quit -f
