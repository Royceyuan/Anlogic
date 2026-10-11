onerror {quit -code 1 -f}
if {[file exists work_video_uart]} {vdel -lib work_video_uart -all}
vlib work_video_uart
vlog -work work_video_uart ../src/common/uart_byte_io.v ../src/secondary/secondary_video_uart_control.v tb_secondary_video_uart_control.v
vsim -c -voptargs=+acc -onfinish stop -lib work_video_uart tb_secondary_video_uart_control
run -all
if {[examine -radix unsigned /tb_secondary_video_uart_control/test_pass] != 1} {quit -code 1 -f}
quit -sim
vsim -c -voptargs=+acc -onfinish stop -gLINK_TEST=0 -lib work_video_uart tb_secondary_video_uart_control
run -all
if {[examine -radix unsigned /tb_secondary_video_uart_control/test_pass] != 1} {quit -code 1 -f}
quit -f
