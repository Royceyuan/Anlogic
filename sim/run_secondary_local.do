if {[file exists work_secondary_local]} {vdel -lib work_secondary_local -all}
vlib work_secondary_local
vlog -work work_secondary_local ../src/secondary/secondary_carousel_controller.v ../src/secondary/secondary_page_overlay.v tb_secondary_carousel_controller.v tb_secondary_stream_carousel.v tb_secondary_page_overlay.v
vsim -c -onfinish stop -lib work_secondary_local tb_secondary_carousel_controller
run -all
quit -sim
vsim -c -onfinish stop -lib work_secondary_local tb_secondary_stream_carousel
run -all
quit -sim
vsim -c -onfinish stop -lib work_secondary_local tb_secondary_page_overlay
run -all
quit -f
