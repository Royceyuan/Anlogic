onerror {quit -code 1 -f}
vlib work_mbp1_reconnect
# Paired regression uses the preserved, real main-board endpoint snapshot.
set main reference_main
foreach {source target mappings} [list \
    $main/mbp1_codec.v codec.v {mbp1_codec mbp1_main_codec} \
    $main/mbp1_main_endpoint.v endpoint.v {mbp1_codec mbp1_main_codec}] {
    set f [open $source r];set contents [read $f];close $f
    set f [open work_mbp1_reconnect/$target w]
    puts $f [string map $mappings $contents];close $f
}
vlog -work work_mbp1_reconnect ../src/ethernet/mbp1_codec.v ../src/ethernet/mbp1_secondary_endpoint.v work_mbp1_reconnect/codec.v work_mbp1_reconnect/endpoint.v ../src/input/key_debounce.v ../src/secondary/secondary_main5e_keys.v tb_mbp1_reconnect.v
vsim -c -voptargs=+acc -onfinish stop -lib work_mbp1_reconnect tb_mbp1_reconnect
run -all
if {[examine -radix unsigned /tb_mbp1_reconnect/test_pass] != 1} {quit -code 1 -f}
quit -f
