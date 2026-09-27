onerror {quit -code 1 -f}
vlib work_main5_resource_overview
vlog +define+SIM -work work_main5_resource_overview ../src/storage/al_dp_ram16.v ../src/storage/rgb565_stream_packer_ready.v ../src/storage/bmp_sdram_row_writer.v tb_bmp_sdram_overview_writer.v
foreach bram {0 1} {
    vsim -onfinish stop -lib work_main5_resource_overview tb_bmp_sdram_overview_writer -gOVERVIEW_BRAM=$bram
    run -all
    quit -sim
}
vlog +define+SIM -work work_main5_resource_overview tb_main5_overview_ram_equivalence.v
vsim -onfinish stop -lib work_main5_resource_overview tb_main5_overview_ram_equivalence
run -all
quit -f
