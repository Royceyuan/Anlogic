onerror {quit -code 1 -f}
if {[file exists work_main3_abort]} {vdel -lib work_main3_abort -all}
vlib work_main3_abort
vlog +define+SIM -work work_main3_abort ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v ../vendor/anlogic_lab6/frame_fifo_read.v ../vendor/anlogic_lab6/frame_fifo_write.v ../vendor/anlogic_lab6/frame_read_write.v ../vendor/anlogic_lab6/al_ip/afifo_16_32_256.v ../vendor/anlogic_lab6/al_ip/afifo_32_16_256.v tb_museum_writer_abort.v
vsim -novopt -c -onfinish stop -lib work_main3_abort tb_museum_writer_abort
run -all
if {[examine -radix unsigned sim:/tb_museum_writer_abort/passed]!=1} {quit -code 1 -f}
quit -code 0 -f
