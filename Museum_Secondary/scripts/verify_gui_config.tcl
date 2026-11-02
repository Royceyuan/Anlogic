# Run with TD's td_commands_prompt.exe. Checks configuration without compilation.
set repo [file normalize [file join [file dirname [info script]] ../..]]
foreach {board project seed pack} {
    Museum_Main museum_main_final 5 high
    Museum_Secondary museum_secondary_final 9 medium
} {
    set entry [file join $repo $board $project.al]
    set f [open $entry r]
    set xml [read $f]
    close $f
    if {![regexp {<Property Enable="true" GenBit="true" EndStep="route" Random="false" Num="1" Init="([0-9]+)" Jobs="1" Save="1" Step="1">} $xml -> configured_seed] || $configured_seed != $seed} {
        error "$board must enable exactly one fixed seed: $seed"
    }
    import_device eagle_s20.db -package EG4S20BG256
    open_project $entry -noanalyze
    foreach {stage param expected} [list gate pack_effort $pack place seed $seed place effort high place opt_timing high place logic_level_opt on route effort routability route fix_hold on] {
        set run [expr {$stage eq "gate" ? "syn_1" : "phy_1"}]
        if {[get_param $stage $param -run $run] ne $expected} {
            error "$board: incorrect $run/$stage/$param"
        }
    }
    report_seed_param
    close_project
    puts "PASS_GUI_CONFIG $board"
}

# Trace the installed TD flow with physical commands replaced by recording stubs.
set template [file join [file dirname [info nameofexecutable]] ../doc/scripts/MultiSeed.tcl]
set f [open $template r]
set flow [read $f]
close $f
if {![regexp {(?s)(proc opt_route_fun .*?)\nproc bitgen_fun} $flow -> route_proc]} {
    error "Cannot locate TD's fixed-seed routing procedure"
}
foreach command {commit_param set_param route fix_hold report_qor report_area update_timing report_timing_status report_timing_summary report_timing_exception report_cells export_db} {
    rename $command __gui_check_$command
    proc $command {args} [format {lappend ::gui_check_calls [linsert $args 0 %s]} $command]
}
eval $route_proc
set prj_name gui_check
set backAnnotation gui_check.adc
set drHoldFix on
set routeSwns 0
set filter off
set gui_check_calls {}
opt_route_fun
set previous -1
foreach call {{set_param route fix_hold off} route fix_hold {set_param route fix_hold on} {update_timing -mode final} {export_db gui_check_pr.db}} {
    set index [lsearch -exact $gui_check_calls $call]
    if {$index <= $previous} {error "Incorrect routing/hold-repair order: $call"}
    set previous $index
}
puts "PASS_GUI_ROUTE_ORDER_NO_COMPILE"
exit
