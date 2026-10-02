onerror {quit -code 1 -f}
if {[file exists work_osd_name_address]} {vdel -lib work_osd_name_address -all}
vlib work_osd_name_address
set source [exec git show aa6292d:src/video/museum_status_osd.v]
set source [string map {"module museum_status_osd #(" "module museum_status_osd_ref #("} $source]
set fd [open work_osd_name_address/museum_status_osd_ref.v w]
puts $fd $source
close $fd
foreach physical {0 1} {
    if {$physical} {
        vlog -work work_osd_name_address D:/TD_6.2.1/sim_release/eg4/eg_phy_glbl.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram.v D:/TD_6.2.1/sim_release/eg4/eg_phy_bram32k.v D:/TD_6.2.1/sim_release/eg4/eg_logic_bram.v
        set defines {}
        set globals glbl
    } else {
        set defines +define+SIM
        set globals {}
    }
    vlog {*}$defines -work work_osd_name_address ../src/video/uart_subtitle_overlay.v ../src/video/museum_status_osd.v work_osd_name_address/museum_status_osd_ref.v tb_osd_name_address_equivalence.v
    foreach percent {0 1} {
        vsim -c -voptargs=+acc -onfinish stop -lib work_osd_name_address -gSHOW_PERCENT=$percent tb_osd_name_address_equivalence {*}$globals
        run -all
        if {[examine -radix binary /tb_osd_name_address_equivalence/test_pass] ne "1"} {quit -code 1 -f}
        quit -sim
    }
}
quit -f
