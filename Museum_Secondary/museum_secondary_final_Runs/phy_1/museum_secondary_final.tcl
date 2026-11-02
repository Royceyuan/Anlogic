# This is multi-seed flow script.
# Noted that only script in editable zone can be changed. 

source ./settings.cfg
proc step_begin { step } {
  set stopFile ".stop.f"
  if {[file isfile .stop.f]} {
    puts ""
    puts " #Halting run"
    puts ""
    return -code error
  }
  set beginFile ".$step.begin.f"
  set platform "$::tcl_platform(platform)"
  set user "$::tcl_platform(user)"
  set pid [pid]
  set host ""
  if { [string equal $platform unix] } {
    if { [info exists ::env(HOSTNAME)] } {
      set host $::env(HOSTNAME)
    }
  } else {
    if { [info exists ::env(COMPUTERNAME)] } {
      set host $::env(COMPUTERNAME)
    }
  }
  set ch [open $beginFile w]
  puts $ch "<?xml version=\"1.0\"?>"
  puts $ch "<ProcessHandle Version=\"1\" Minor=\"0\">"
  puts $ch "    <Process Ownner=\"$user\" Host=\"$host\" Pid=\"$pid\">"
  puts $ch "    </Process>"
  puts $ch "</ProcessHandle>"
  close $ch
}
proc step_end { step } {
  set endFile ".$step.end.f"
  set ch [open $endFile w]
  close $ch
}
proc step_error { step } {
  set errorFile ".$step.error.f"
  set ch [open $errorFile w]
  close $ch
}
set stepList {opt_place opt_route bitgen}
set l [lsearch $stepList $start_step]
set r [lsearch $stepList $end_step]
proc prepare { step } {
  upvar device_name device_name
  upvar package_name package_name
  upvar speed speed
  upvar prj_name prj_name
  upvar parent parent
  upvar phyPath phyPath
  upvar seed seed
  if { ![info exists speed] } { import_device $device_name -package $package_name }\
  else { import_device $device_name -package $package_name -speed $speed }
  cd $phyPath
  open_project ${prj_name}.prj -noanalyze
  cd $phyPath/seed_$seed
  import_db $parent/${prj_name}_gate.db
  set_param place seed $seed
}
proc opt_place_fun {} {
  upvar prj_name prj_name
  upvar phyWildParams phyWildParams
  upvar cwcList cwcList
  upvar placeSwns placeSwns
  upvar congestion congestion
  upvar filter filter
  upvar chipDebugger chipDebugger
  upvar bkaADCList bkaADCList
  commit_param -step place
  if { [info exists phyWildParams] } {
    set i 0
    while {$i < [llength $phyWildParams]} {
      set_param [lindex $phyWildParams $i] [lindex $phyWildParams [expr $i + 1]] [lindex $phyWildParams [expr $i + 2]]
      incr i 3
    }
  }
  if { ![info exists chipDebugger] } { insert_debugger } \
  else { insert_debugger $chipDebugger }
  if { [info exists bkaADCList] } { 
    clear_inst_adc
    foreach adc $bkaADCList { read_adc $adc } 
  }

### Editable zone for opt_place ###
  place
  update_timing -mode manhattan
  report_timing_summary -file ${prj_name}_place.timing
  report_timing_status -file ${prj_name}_place.ts
  report_area -io_info -file ${prj_name}_phy.area
  if { [string equal $filter on] } { flow_continue_check -step place -wns $placeSwns -congestion $congestion }
###################################

  export_db ${prj_name}_place.db
}
proc opt_route_fun {} {
  upvar prj_name prj_name
  upvar backAnnotation backAnnotation
  upvar drHoldFix drHoldFix
  upvar routeSwns routeSwns
  upvar filter filter
  commit_param -step route

### Editable zone for opt_route ###
  if { [string equal $drHoldFix on] } { 
    set_param route fix_hold off
    set_param flow qor_monitor off
  }
  route
  if { [string equal $drHoldFix on] } {
    if { [string equal $filter on] } { flow_continue_check -step route -wns $routeSwns -name ${prj_name} }
    fix_hold
    set_param route fix_hold on
    set_param flow qor_monitor on
    report_qor -step route -file route.qor
  }
  report_area -io_info -file ${prj_name}_phy.area
  update_timing -mode final
  report_timing_status -file ${prj_name}_phy.ts
  report_timing_summary -file ${prj_name}_pr.timing
  report_timing_exception -file ${prj_name}_exception.timing
  report_cells -bram -dsp -export_adc -file $backAnnotation
###################################

  export_db ${prj_name}_pr.db
}
proc bitgen_fun {} {
  upvar prj_name prj_name
  upvar cpcList cpcList
  commit_param -step bitgen
  if { [info exists cpcList] } {
    import_chipprobe_config $cpcList
    compile_probe
  }

### Editable zone for bitgen ###
  bitgen -bit $prj_name.bit
################################
  upvar chipDebugger chipDebugger
  if { ![info exists chipDebugger] } {
    setup_debugger
  } else { setup_debugger $chipDebugger }
}
foreach s [lrange $stepList $l $r] {
  step_begin $s
  set ACTIVESTEP $s
  set rc [catch {
    if { [string equal $s $start_step] } { prepare $s }
    ${s}_fun
  } RESULT]
  if { $rc } {
    step_error $s
    return -code error $RESULT
  } else {
    step_end $s
    unset ACTIVESTEP
  }
}

flow_status -file flow.status
exit
