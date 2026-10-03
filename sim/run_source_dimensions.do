onerror {quit -code 1 -f}
set root [file normalize ..]
set out $root/_build_source_dimensions
file mkdir $out
set fd [open $root/src/memory/museum_media_core.v r]
quietly set source [read $fd]
close $fd
set first [string first {module museum_source_dimensions (} $source]
if {$first<0} {error "Missing dimension table"}
set fd [open $out/museum_source_dimensions.v w]
puts $fd [string range $source $first end]
close $fd
foreach primitive {0 1} {
    set lib $out/work_$primitive
    vlib $lib
    if {$primitive} {
        vlog -work $lib D:/TD_6.2.1/sim_release/eg4/eg_logic_dram.v
        vlog -work $lib $out/museum_source_dimensions.v tb_source_dimensions.v
    } else {
        vlog +define+SIM -work $lib $out/museum_source_dimensions.v tb_source_dimensions.v
    }
    vsim -voptargs=+acc -onfinish stop -lib $lib tb_source_dimensions
    run -all
    if {[examine -radix unsigned sim:/tb_source_dimensions/test_pass] != 1} {quit -code 1 -f}
    quit -sim
}
quit -code 0 -f
