onerror {quit -code 1 -f}
vlib sim/work_secondary_frame_store_alignment
vlog -work sim/work_secondary_frame_store_alignment vendor/anlogic_lab6/al_ip/afifo_16_32_256.v vendor/anlogic_lab6/al_ip/afifo_32_16_256.v vendor/anlogic_lab6/frame_read_write.v vendor/anlogic_lab6/frame_fifo_read.v vendor/anlogic_lab6/frame_fifo_write.v sim/tb_secondary_frame_store_alignment.v
quietly set input [open src/memory/anlogic_frame_store.v r]
quietly set wrapper [read $input]
close $input
quietly set connection {\.Sdr_rd_dout[ \t]*\([ \t]*sdr_rd_dout_q[ \t]*\)}
if {[regexp -all $connection $wrapper] != 1} {error "expected exactly one aligned frame input"}
quietly regsub $connection $wrapper {.Sdr_rd_dout(sdr_rd_dout)} unaligned
quietly set baseline sim/work_secondary_frame_store_alignment/anlogic_frame_store_unaligned.v
quietly set output [open $baseline w]
puts $output $unaligned
close $output
foreach test [list [list $baseline 1] [list src/memory/anlogic_frame_store.v 0]] {
    lassign $test source expected
    vlog -work sim/work_secondary_frame_store_alignment $source
    vsim -c -voptargs=+acc -onfinish stop -lib sim/work_secondary_frame_store_alignment tb_secondary_frame_store_alignment -gEXPECT_ERROR=$expected
    run -all
    if {[examine -radix unsigned /tb_secondary_frame_store_alignment/checks_passed] != 1} {quit -code 1 -f}
    quit -sim
}
quit -f
