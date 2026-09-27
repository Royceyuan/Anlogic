onerror {quit -code 1 -f}
vlib work_mbp1_equivalence
# Freeze the pre-optimization endpoint; do not use the candidate as its oracle.
set old [exec git show 62ee8bf:src/ethernet/mbp1_main_endpoint.v]
set fd [open work_mbp1_equivalence/reference.v w]
puts $fd [string map {"module mbp1_main_endpoint #(" "module mbp1_main_endpoint_reference #("} $old]
close $fd
vlog -work work_mbp1_equivalence ../src/ethernet/mbp1_codec.v ../src/ethernet/mbp1_main_endpoint.v work_mbp1_equivalence/reference.v tb_mbp1_endpoint_equivalence.v
foreach hold {0 1} {
    vsim -voptargs=+acc -onfinish stop -lib work_mbp1_equivalence tb_mbp1_endpoint_equivalence -gHOLD=$hold
    run -all
    if {[examine -radix unsigned sim:/tb_mbp1_endpoint_equivalence/test_pass] != 1} {quit -code 1 -f}
    quit -sim
}
quit -f
