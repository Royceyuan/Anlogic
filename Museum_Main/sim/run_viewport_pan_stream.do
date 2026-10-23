onerror {quit -code 1 -f}
if {[file exists work_main5_pan_stream]} {vdel -lib work_main5_pan_stream -all}
vlib work_main5_pan_stream
vlog +define+SIM -work work_main5_pan_stream ../src/storage/al_dp_ram32.v ../src/video/video_timing_programmable_pclk.v ../src/video/linebuf_scaler_960x540_to_1280x720.v tb_linebuf_scaler_zoom_stream.v
vsim -c -voptargs=+acc -onfinish stop -lib work_main5_pan_stream tb_linebuf_scaler_zoom_stream
run -all
if {[examine -radix binary /tb_linebuf_scaler_zoom_stream/test_pass] ne "1"} {quit -code 1 -f}
quit -sim
# Repeat with the actual non-SIM wrapper and official synchronous BRAM model.
if {[file exists work_main5_pan_physical]} {vdel -lib work_main5_pan_physical -all}
vlib work_main5_pan_physical
vlog -work work_main5_pan_physical D:/TD_6.2.1/sim_release/eg4/eg_phy_bram.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram32k.v D:/TD_6.2.1/sim_release/eg4/eg_logic_bram.v ../src/storage/al_dp_ram32.v ../src/video/video_timing_programmable_pclk.v ../src/video/linebuf_scaler_960x540_to_1280x720.v tb_linebuf_scaler_zoom_stream.v
vsim -c -voptargs=+acc -onfinish stop -lib work_main5_pan_physical tb_linebuf_scaler_zoom_stream
run -all
if {[examine -radix binary /tb_linebuf_scaler_zoom_stream/test_pass] ne "1"} {quit -code 1 -f}
quit -f
