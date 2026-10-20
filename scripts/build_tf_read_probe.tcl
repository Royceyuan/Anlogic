# Run from the secondary root with td_commands_prompt.exe.
import_device eagle_s20.db -package EG4S20BG256
set root .
set result _build_tf_read_probe
file mkdir $result
open_project secondary_tf_read_probe.al -single_run
load_run_param -run syn_1
elaborate -top top_secondary_tf_read_probe
read_adc constraints/secondary_tf_read_probe.adc
clear_sdc -user
read_sdc constraints/secondary_tf_read_probe.sdc
optimize_rtl
optimize_gate -packarea [file join $result gate.area]
legalize_phy_inst
update_timing
if {[llength [get_clocks clk_50m]]!=1 || [llength [get_clocks sd_fast]]!=1} {error "Missing SD probe clock constraints"}
report_area -file [file join $result gate_resources.area]
set_param place seed 8
place
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_area -io_info -file [file join $result final.area]
report_timing_summary -file [file join $result final.timing]
report_timing_status -file [file join $result final.ts]
flow_status -file [file join $result final.status]
export_db [file join $result final.db]
# Bit generation is a separate step after reviewing the reports.
exit
