if {[file exists work_secondary_native720_media]} {vdel -lib work_secondary_native720_media -all}
vlib work_secondary_native720_media
vlog +define+SIM -work work_secondary_native720_media ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_block_writer.v ../src/storage/bmp_sdram_row_writer.v tb_fat32_bmp_adaptive_loader.v
vsim -c -onfinish stop -lib work_secondary_native720_media tb_fat32_bmp_adaptive_loader -gIMAGE_W=1280 -gIMAGE_H=720 -gBASE_W=1280 -gBASE_H=720 -gHIRES=0 -gIMAGE_ADDR_BITS=21 -gSOURCE_W=1280 -gSOURCE_H=720 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 -gIMAGE_INDEX=0 -gMULTI_IMAGE_BMP=1 -gRESOURCE_OPT_CONSTANT_MULT=1
run -all
quit -sim
vsim -c -onfinish stop -lib work_secondary_native720_media tb_fat32_bmp_adaptive_loader -gIMAGE_W=1280 -gIMAGE_H=720 -gBASE_W=1280 -gBASE_H=720 -gHIRES=0 -gIMAGE_ADDR_BITS=21 -gSOURCE_W=1280 -gSOURCE_H=720 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 -gIMAGE_INDEX=10 -gMULTI_IMAGE_BMP=1 -gRESOURCE_OPT_CONSTANT_MULT=1
run -all
quit -f
