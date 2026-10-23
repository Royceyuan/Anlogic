onerror {quit -code 1 -f}
if {[file exists work_subtitle_tf_card]} {vdel -lib work_subtitle_tf_card -all}
vlib work_subtitle_tf_card
vlog +define+SIM -work work_subtitle_tf_card ../src/video/uart_subtitle_overlay.v ../src/video/museum_subtitle_overlay.v tb_subtitle_tf_card.v
vsim -c -voptargs=+acc -onfinish stop -lib work_subtitle_tf_card tb_subtitle_tf_card
run -all
if {[examine -radix binary /tb_subtitle_tf_card/test_pass] ne "1"} {quit -code 1 -f}
quit -f
