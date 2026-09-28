onerror {quit -code 1 -f}
vlib work_main5_resource_adaptive
vlog +define+SIM -work work_main5_resource_adaptive ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_block_writer.v ../src/storage/bmp_sdram_row_writer.v tb_fat32_bmp_adaptive_loader.v
foreach ram {9K 32K} {
foreach dims {{65 47} {31 79} {96 72} {16 16}} {
    foreach orientation {0 1} {
        vsim -onfinish stop -lib work_main5_resource_adaptive tb_fat32_bmp_adaptive_loader -gIMAGE_W=64 -gIMAGE_H=48 -gSOURCE_W=[lindex $dims 0] -gSOURCE_H=[lindex $dims 1] -gTOP_DOWN=$orientation -gADAPTIVE_RAM_IMPLEMENT=$ram
        run -all
        quit -sim
    }
}
}
vsim -onfinish stop -lib work_main5_resource_adaptive tb_fat32_bmp_adaptive_loader -gIMAGE_W=960 -gIMAGE_H=540 -gIMAGE_ADDR_BITS=19 -gSOURCE_W=1919 -gSOURCE_H=1080 -gTOP_DOWN=1 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 -gRESOURCE_OPT_CONSTANT_MULT=1 -gADAPTIVE_RAM_IMPLEMENT=32K
run -all
quit -f
