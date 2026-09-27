onerror {quit -code 1 -f}
if {[file exists work_main5_osd_vendor]} {vdel -lib work_main5_osd_vendor -all}
vlib work_main5_osd_vendor
vlog -work work_main5_osd_vendor D:/TD_6.2.1/sim_release/eg4/eg_phy_glbl.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram32k.v D:/TD_6.2.1/sim_release/eg4/eg_logic_bram.v ../src/video/uart_subtitle_overlay.v ../src/video/museum_status_osd.v tb_museum_status_osd.v
vsim -c -voptargs=+acc -onfinish stop -lib work_main5_osd_vendor tb_museum_status_osd glbl
run -all
if {[examine -radix binary /tb_museum_status_osd/test_pass] ne "1"} {quit -code 1 -f}
quit -f
