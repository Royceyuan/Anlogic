onerror {quit -code 1 -f}
if {[file exists work_zoom_osd_physical]} {vdel -lib work_zoom_osd_physical -all}
vlib work_zoom_osd_physical
vlog -work work_zoom_osd_physical D:/TD_6.2.1/sim_release/eg4/eg_phy_glbl.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram32k.v D:/TD_6.2.1/sim_release/eg4/eg_logic_bram.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_status_osd.v tb_museum_status_osd.v
vsim -voptargs=+acc -onfinish stop work_zoom_osd_physical.tb_museum_status_osd work_zoom_osd_physical.glbl
run -all
if {[examine -radix binary /tb_museum_status_osd/test_pass] ne "1"} {quit -code 1 -f}
quit -f
