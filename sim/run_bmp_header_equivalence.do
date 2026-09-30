onerror {quit -code 1 -f}
file mkdir work_bmp_header
# Generate the comparison fixture from the pushed, timing-clean baseline.
quietly set source [exec git show a0a6832:src/storage/fat32_image_loader.v]
quietly regsub {module fat32_image_loader #} $source {module fat32_image_loader_reference #} source
set fixture [open work_bmp_header/fat32_image_loader_reference.v w]
puts $fixture $source
close $fixture
vlib work_bmp_header/lib
vlog +define+SIM -work work_bmp_header/lib ../src/storage/al_dp_ram16.v ../src/storage/adaptive_row_ram.v ../src/storage/fat32_image_loader.v work_bmp_header/fat32_image_loader_reference.v tb_bmp_header_equivalence.v
foreach mode {0 1} {
    vsim -novopt -onfinish stop -lib work_bmp_header/lib tb_bmp_header_equivalence -gADAPTIVE_MODE=$mode
    run -all
    if {[examine -radix unsigned /tb_bmp_header_equivalence/passed] != 1} {quit -code 1 -f}
    quit -sim
}
quit -f
