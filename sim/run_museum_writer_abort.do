if {[file exists work_main3_abort]} {vdel -lib work_main3_abort -all}
vlib work_main3_abort
vlog +define+SIM -work work_main3_abort ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v tb_museum_writer_abort.v
vsim -c -lib work_main3_abort tb_museum_writer_abort -do "run -all; quit -f"
