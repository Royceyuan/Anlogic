if {[file exists work_osd1280]} {vdel -lib work_osd1280 -all}
vlib work_osd1280
vlog -work work_osd1280 ../src/video/osd_status.v ../src/video/osd_status_rgb888.v ../src/video/osd_status_1280_pipe.v tb_osd_1280_dimensions.v
vsim -c -lib work_osd1280 tb_osd_1280_dimensions
run -all
quit -f
