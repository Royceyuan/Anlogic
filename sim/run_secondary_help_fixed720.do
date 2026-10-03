onerror {quit -code 1 -f}
vlib work_secondary_help_fixed720
vlog +define+SIM +incdir+.. -work work_secondary_help_fixed720 ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v ../src/secondary/secondary_help_overlay.v tb_fat32_bmp_adaptive_loader.v
set common {-gFIXED_MODE=1 -gBASE_W=160 -gBASE_H=90 -gIMAGE_W=1280 -gIMAGE_H=720 -gIMAGE_ADDR_BITS=21 -gBMP_MAX_WIDTH=1280 -gBMP_MAX_HEIGHT=720 -gMULTI_IMAGE_BMP=1 -gRESOURCE_OPT_CONSTANT_MULT=1}
set backdrop {-gHELP_MODE=1 -gHIRES=0 -gIMAGE_INDEX=11 -gSOURCE_W=160 -gSOURCE_H=90 -gDISK_BYTES=2097152}
foreach variant {
    {}
    {-gTOP_DOWN=1 -gHEADER_OFFSET=138 -gFRAGMENTED=1}
    {-gSOURCE_W=161 -gEXPECT_ERROR=1}
    {-gFILE_TRIM=1 -gEXPECT_ERROR=1}
    {-gBITS_PER_PIXEL=16 -gEXPECT_ERROR=1}
    {-gCOMPRESSION=1 -gEXPECT_ERROR=1}
} {
    eval vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_help_fixed720 tb_fat32_bmp_adaptive_loader $common $backdrop $variant
    run -all
    if {[examine -radix unsigned /tb_fat32_bmp_adaptive_loader/checks_passed] != 1} {quit -code 1 -f}
    quit -sim
}
set native {-gHIRES=1 -gSOURCE_W=1280 -gSOURCE_H=720 -gDISK_BYTES=8388608}
foreach variant {{-gIMAGE_INDEX=0} {-gIMAGE_INDEX=5 -gTOP_DOWN=1 -gWRITE_STALL=1 -gFRAGMENTED=1} {-gIMAGE_INDEX=10}} {
    eval vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_help_fixed720 tb_fat32_bmp_adaptive_loader $common $native $variant
    run -all
    if {[examine -radix unsigned /tb_fat32_bmp_adaptive_loader/checks_passed] != 1} {quit -code 1 -f}
    quit -sim
}
quit -f
