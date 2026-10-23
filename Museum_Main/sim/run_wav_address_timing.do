onerror {quit -code 1 -f}
if {[file exists work_wav_address]} {vdel -lib work_wav_address -all}
vlib work_wav_address
vlog -work work_wav_address ../src/audio/fat32_wav_streamer.v tb_fat32_wav_streamer.v tb_wav_cluster_address.v
foreach reuse {0 1} {
    vsim -voptargs=+acc -onfinish stop -lib work_wav_address -gREUSE_GEOMETRY=$reuse tb_fat32_wav_streamer
    run -all
    quit -sim
}
vsim -voptargs=+acc -onfinish stop -lib work_wav_address tb_wav_cluster_address
run -all
if {[examine -radix unsigned /tb_wav_cluster_address/test_pass] != 1} {quit -code 1 -f}
quit -f
