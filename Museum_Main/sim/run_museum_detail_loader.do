if {[file exists work_main2_detail]} {vdel -lib work_main2_detail -all}
vlib work_main2_detail
vmap work work_main2_detail
vlog +define+SIM -work work_main2_detail ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_block_writer.v ../src/storage/bmp_sdram_row_writer.v
vlog -work work_main2_detail tb_fat32_bmp_adaptive_loader.v
vsim -lib work_main2_detail tb_fat32_bmp_adaptive_loader -gIMAGE_W=64 -gIMAGE_H=48 -gIMAGE_ADDR_BITS=12 -gSOURCE_W=96 -gSOURCE_H=96 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=4194304 -gMUSEUM_DETAIL=1 -gARTIFACT_INDEX=4 -gDETAIL_INDEX=3
run -all
quit -f
