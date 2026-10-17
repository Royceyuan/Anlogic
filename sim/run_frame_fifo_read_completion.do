onerror {quit -code 1 -f}
if {[file exists work_read_completion]} {vdel -lib work_read_completion -all}
vlib work_read_completion
vlog -work work_read_completion ../vendor/anlogic_lab6/frame_fifo_read.v tb_frame_fifo_read_completion.v
vsim -novopt -c -onfinish stop -lib work_read_completion tb_frame_fifo_read_completion
run -all
if {[examine -radix unsigned sim:/tb_frame_fifo_read_completion/passed]!=1} {quit -code 1 -f}
quit -code 0 -f
