onerror {quit -code 1 -f}
if {[file exists work_secondary_help]} {vdel -lib work_secondary_help -all}
vlib work_secondary_help
vlog +define+SIM +incdir+.. -work work_secondary_help ../src/secondary/secondary_help_overlay.v tb_secondary_help_overlay.v
vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_help tb_secondary_help_overlay
run -all
if {[examine -radix unsigned /tb_secondary_help_overlay/test_pass] != 1} {quit -code 1 -f}
quit -sim
vlog +define+SIM -work work_secondary_help ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v ../src/storage/bmp_row_buffer.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v tb_fat32_bmp_adaptive_loader.v
vsim -c -onfinish stop -lib work_secondary_help tb_fat32_bmp_adaptive_loader -gIMAGE_W=1280 -gIMAGE_H=720 -gBASE_W=1280 -gBASE_H=720 -gIMAGE_ADDR_BITS=21 -gSOURCE_W=160 -gSOURCE_H=90 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 -gIMAGE_INDEX=11 -gMULTI_IMAGE_BMP=1 -gRESOURCE_OPT_CONSTANT_MULT=1
run -all
quit -sim
vsim -c -onfinish stop -lib work_secondary_help tb_fat32_bmp_adaptive_loader -gIMAGE_W=1280 -gIMAGE_H=720 -gBASE_W=1280 -gBASE_H=720 -gIMAGE_ADDR_BITS=21 -gSOURCE_W=160 -gSOURCE_H=90 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 -gIMAGE_INDEX=11 -gMULTI_IMAGE_BMP=1 -gRESOURCE_OPT_CONSTANT_MULT=1 -gTOP_DOWN=1
run -all
quit -f
