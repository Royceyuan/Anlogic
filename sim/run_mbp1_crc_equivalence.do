onerror {quit -code 1 -f}
set root [file normalize ..]
source $root/experiments/mbp1_crc/prepare.tcl
vlib work_mbp1_crc
vlog -work work_mbp1_crc $candidate tb_mbp1_codec.v
vsim -voptargs=+acc -onfinish stop -lib work_mbp1_crc tb_mbp1_codec -gEXHAUSTIVE_CRC=1
run -all
if {[examine -radix unsigned sim:/tb_mbp1_codec/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
