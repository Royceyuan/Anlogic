onerror {quit -code 1 -f}
vlib work_secondary_fixed720
vlog +define+SIM -work work_secondary_fixed720 ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v tb_fat32_bmp_adaptive_loader.v
set native {-gFIXED_MODE=1 -gIMAGE_W=1280 -gIMAGE_H=720 -gBASE_W=1280 -gBASE_H=720 -gHIRES=0 -gIMAGE_ADDR_BITS=21 -gSOURCE_W=1280 -gSOURCE_H=720 -gBMP_MAX_WIDTH=1280 -gBMP_MAX_HEIGHT=720 -gDISK_BYTES=8388608 -gMULTI_IMAGE_BMP=1}
foreach variant {
    {-gIMAGE_INDEX=0}
    {-gIMAGE_INDEX=5 -gTOP_DOWN=1 -gHEADER_OFFSET=138 -gWRITE_STALL=1 -gFRAGMENTED=1}
    {-gIMAGE_INDEX=10}
    {-gSOURCE_W=960 -gSOURCE_H=540 -gEXPECT_ERROR=1}
    {-gFILE_TRIM=1 -gEXPECT_ERROR=1}
    {-gBITS_PER_PIXEL=16 -gEXPECT_ERROR=1}
    {-gCOMPRESSION=1 -gEXPECT_ERROR=1}
    {-gHEADER_OFFSET=20 -gEXPECT_ERROR=1}
} {
    eval vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_fixed720 tb_fat32_bmp_adaptive_loader $native $variant
    run -all
    if {[examine -radix unsigned /tb_fat32_bmp_adaptive_loader/checks_passed] != 1} {quit -code 1 -f}
    quit -sim
}
quit -f
