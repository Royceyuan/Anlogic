onerror {quit -code 1 -f}
if {[file exists work_video_geometry]} {vdel -lib work_video_geometry -all}
vlib work_video_geometry
vlog +define+SIM -work work_video_geometry ../src/storage/al_dp_ram32.v ../src/video/linebuf_scaler_960x540_to_1280x720.v ../src/video/audio_visualizer_overlay.v tb_linebuf_scaler_zoom.v tb_linebuf_scaler_zoom_stream.v tb_audio_visualizer_overlay.v
foreach test {tb_audio_visualizer_overlay tb_linebuf_scaler_zoom tb_linebuf_scaler_zoom_stream} {
    vsim -novopt -onfinish stop -lib work_video_geometry $test
    run -all
    if {[examine -radix unsigned /$test/test_pass] != 1} {quit -code 1 -f}
    quit -sim
}
quit -f
