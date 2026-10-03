onerror {quit -code 1 -f}
set out ../_build_source_dimensions/row_hit
file mkdir $out
set fd [open ../src/video/linebuf_scaler_960x540_to_1280x720.v r]
quietly set candidate [read $fd]
close $fd
quietly set reference [exec git show ffc0f06:src/video/linebuf_scaler_960x540_to_1280x720.v]
foreach name {row_hit_candidate row_hit_reference} {
    if {$name eq "row_hit_candidate"} {
        quietly set source $candidate
        set anchor {wire hit0 =}
    } else {
        quietly set source $reference
        set anchor {assign source_row_hit}
    }
    set first [string first $anchor $source]
    set last [string first {assign free_slot0} $source $first]
    if {$first<0 || $last<$first} {error "Row hit decode anchors changed"}
    set fd [open $out/$name.v w]
    puts $fd "module $name ("
    puts $fd {input wire in_picture, display_epoch,
input wire [2:0] slot_valid, slot_epoch,
input wire [9:0] slot_tag0,slot_tag1,slot_tag2,
input wire signed [10:0] mapped_y,
output wire source_row_hit, output wire [1:0] source_row_slot);}
    puts $fd [string range $source $first [expr {$last-1}]]
    puts $fd {endmodule}
    close $fd
}
vlib $out/work
vlog -work $out/work $out/row_hit_candidate.v $out/row_hit_reference.v tb_source_row_hit.v
vsim -voptargs=+acc -onfinish stop -lib $out/work tb_source_row_hit
run -all
if {[examine -radix unsigned sim:/tb_source_row_hit/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
