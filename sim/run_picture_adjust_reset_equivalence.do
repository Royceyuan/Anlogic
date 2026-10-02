onerror {quit -code 1 -f}
if {[file exists work_picture_reset]} {vdel -lib work_picture_reset -all}
vlib work_picture_reset
set source [exec git show 13494cd:src/video/rgb888_picture_adjust.v]
set source [string map {"module rgb888_picture_adjust (" "module rgb888_picture_adjust_ref ("} $source]
set fd [open work_picture_reset/reference.v w]
puts $fd $source
close $fd
vlog -work work_picture_reset ../src/video/rgb888_picture_adjust.v work_picture_reset/reference.v tb_picture_adjust_reset_equivalence.v
vsim -c -voptargs=+acc -onfinish stop -lib work_picture_reset tb_picture_adjust_reset_equivalence
run -all
if {[examine -radix binary /tb_picture_adjust_reset_equivalence/test_pass] ne "1"} {quit -code 1 -f}
quit -f
