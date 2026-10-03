onerror {quit -code 1 -f}
vlib work_secondary_page_switch
# Exercise the actual production video state machine, isolated from PLL,
# encrypted SDRAM and HDMI primitives. No copied FSM is kept in the test.
quietly set input [open ../src/memory/sdram_bmp_row_top_v66.v r]
quietly set source [read $input]
close $input
quietly set start [string first {always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        ready_ff1} $source]
quietly set end [string first {video_timing_640x480_pclk #(} $source $start]
if {$start < 0 || $end < $start} {error "video FSM extraction failed"}
quietly set fsm [string range $source $start [expr {$end - 1}]]
quietly set output [open work_secondary_page_switch/video_fsm.vh w]
foreach declaration [regexp -all -inline -line {^reg[^;]*;} $source] {
    foreach name [regexp -all -inline {[a-zA-Z_][a-zA-Z_0-9]*} $declaration] {
        if {$name ne "reg" && [regexp "\\m$name\\M" $fsm]} {puts $output $declaration; break}
    }
}
foreach name {museum_switch_transition_mode transition_midpoint transition_end transition_midpoint_ready} {
    if {![regexp [format {wire(?: \[[^\]]*\])? %s[^;]*;} $name] $source declaration]} {
        error "missing $name"
    }
    puts $output $declaration
}
puts $output $fsm
close $output
vlog +incdir+work_secondary_page_switch -work work_secondary_page_switch tb_secondary_page_switch.v
vsim -c -voptargs=+acc -onfinish stop -lib work_secondary_page_switch tb_secondary_page_switch
run -all
if {[examine -radix unsigned /tb_secondary_page_switch/checks_passed] != 1} {quit -code 1 -f}
quit -f
