if {[file exists work_uart_subtitle_720p_v72]} {vdel -lib work_uart_subtitle_720p_v72 -all}
vlib work_uart_subtitle_720p_v72
vlog +define+SIM -work work_uart_subtitle_720p_v72 ../src/video/uart_subtitle_overlay.v tb_uart_subtitle_overlay.v
vsim -c -lib work_uart_subtitle_720p_v72 tb_uart_subtitle_overlay -gBPP=2 -gBRAM_READ_REG=0 -gX_START=240 -gRESOURCE_OPT_ADDR=1 -gDISPLAY_WIDTH=1280 -gFULL_WIDTH_SCROLL=1
run -all
quit -f
