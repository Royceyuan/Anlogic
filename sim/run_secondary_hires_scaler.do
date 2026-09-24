if {[file exists work_secondary_scaler]} {vdel -lib work_secondary_scaler -all}
vlib work_secondary_scaler
vlog +define+SIM -work work_secondary_scaler ../src/storage/al_dp_ram32.v ../src/video/linebuf_scaler_960x540_to_1280x720.v tb_linebuf_scaler_zoom_stream.v
vsim -c -onfinish stop -lib work_secondary_scaler tb_linebuf_scaler_zoom_stream
run -all
quit -f
