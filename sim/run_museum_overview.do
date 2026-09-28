if {[file exists work_main1_overview]} {vdel -lib work_main1_overview -all}
vlib work_main1_overview
vlog -work work_main1_overview ../src/video/museum_overview_controller.v tb_museum_overview_controller.v
vlog -work work_main1_overview ../src/video/museum_overview_overlay.v tb_museum_overview_overlay.v
vlog -work work_main1_overview ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v tb_bmp_sdram_overview_writer.v
vsim -c -onfinish stop -lib work_main1_overview tb_museum_overview_controller
run -all
quit -sim
vsim -c -onfinish stop -lib work_main1_overview tb_bmp_sdram_overview_writer
run -all
quit -sim
vsim -c -onfinish stop -lib work_main1_overview tb_museum_overview_overlay
run -all
quit -f
