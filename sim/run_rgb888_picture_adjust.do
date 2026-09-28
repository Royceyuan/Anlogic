vlib work
vlog ../src/video/rgb888_picture_adjust.v tb_rgb888_picture_adjust.v
vsim -c tb_rgb888_picture_adjust -do "run -all; quit -f"
