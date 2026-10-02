onerror {quit -code 1 -f}
if {[file exists work_viewport_request]} {vdel -lib work_viewport_request -all}
vlib work_viewport_request
# Compare the actual request branches, not a hand-copied proposed formula.
set fd [open ../src/memory/museum_media_core.v r]
set candidate [read $fd]
close $fd
set reference [exec git show 6c46807:src/memory/museum_media_core.v]
foreach name {viewport_request_dut viewport_request_ref} {
    if {$name eq "viewport_request_dut"} {set source $candidate} else {set source $reference}
    set first [string first {end else if (ENABLE_MULTI_FRAME_PRELOAD && video_run &&
                     !overview_enable_video} $source]
    set last [string first {end else if (ENABLE_DUAL_FRAME_PRELOAD && video_run &&} $source $first]
    if {$first < 0 || $last < 0} {error "Viewport request extraction failed"}
    set branch [string range $source [expr {$first+9}] [expr {$last+2}]]
    regsub -all {\mswitch_pending\M[ \t]*<=} $branch {next_switch_pending <=} branch
    set fd [open work_viewport_request/$name.v w]
    puts $fd "module $name ("
    puts $fd {input wire clk, rst_n, ENABLE_MULTI_FRAME_PRELOAD, ENABLE_MAIN5_REMOTE,
input wire video_run, overview_enable_video, transition_active,
input wire detail_zoom_2x_ff2, display_zoom_2x, switch_pending, main5_pan_changed,
input wire [3:0] display_media_index,
input wire display_frame_index,
input wire [15:0] display_source_width_bcd, display_source_height_bcd,
input wire signed [8:0] main5_pan_x_video, main5_pan_y_video,
output wire [74:0] result);
reg [3:0] pending_media_index;
reg pending_frame_index, pending_zoom_2x, next_switch_pending, direct_switch_pending;
reg [15:0] pending_source_width_bcd, pending_source_height_bcd;
reg signed [8:0] pending_pan_x, pending_pan_y;
reg [2:0] transition_mode;
reg fade_out_active;
reg [4:0] fade_level;
reg [7:0] transition_progress;
assign result={pending_media_index,pending_frame_index,pending_source_width_bcd,
pending_source_height_bcd,pending_zoom_2x,pending_pan_x,pending_pan_y,
next_switch_pending,direct_switch_pending,transition_mode,fade_out_active,
fade_level,transition_progress};
always @(posedge clk or negedge rst_n)
if(!rst_n) {pending_media_index,pending_frame_index,pending_source_width_bcd,
pending_source_height_bcd,pending_zoom_2x,pending_pan_x,pending_pan_y,
next_switch_pending,direct_switch_pending,transition_mode,fade_out_active,
fade_level,transition_progress} <= 75'd0;
else}
    puts $fd $branch
    puts $fd {endmodule}
    close $fd
}
vlog -work work_viewport_request work_viewport_request/viewport_request_dut.v work_viewport_request/viewport_request_ref.v tb_viewport_request_equivalence.v
vsim -c -voptargs=+acc -onfinish stop -lib work_viewport_request tb_viewport_request_equivalence
run -all
if {[examine -radix binary /tb_viewport_request_equivalence/test_pass] ne "1"} {quit -code 1 -f}
quit -f
