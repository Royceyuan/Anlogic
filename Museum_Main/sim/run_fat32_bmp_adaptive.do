if {[file exists work_bmp_adaptive_v72]} {vdel -lib work_bmp_adaptive_v72 -all}
vlib work_bmp_adaptive_v72
vlog +define+SIM -work work_bmp_adaptive_v72 ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_block_writer.v ../src/storage/bmp_sdram_row_writer.v
vlog -work work_bmp_adaptive_v72 tb_fat32_bmp_adaptive_loader.v
vsim -lib work_bmp_adaptive_v72 tb_fat32_bmp_adaptive_loader -gIMAGE_W=960 -gIMAGE_H=540 -gIMAGE_ADDR_BITS=19 -gSOURCE_W=1920 -gSOURCE_H=1080 -gTOP_DOWN=0 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 -gUSE_BLOCK_WRITER=0 -gRESOURCE_OPT_CONSTANT_MULT=1
run -all
quit -f
