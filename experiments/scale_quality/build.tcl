# Invoke from repository root; SCALE_MODE is horizontal or bilinear.
set mode $env(SCALE_MODE)
if {$mode ni {horizontal bilinear}} {error "Invalid SCALE_MODE"}
set out ./_build_scale_quality/$mode
file mkdir $out
import_device eagle_s20.db -package EG4S20BG256
if {$mode eq "horizontal"} {
    read_verilog -file ./experiments/scale_quality/rgb565_interpolate.v -define SCALE_HORIZONTAL
} else {
    read_verilog -file ./experiments/scale_quality/rgb565_interpolate.v
}
read_sdc ./experiments/scale_quality/timing.sdc
optimize_rtl
set_param gate pack_effort high
optimize_gate -packarea $out/gate.area
legalize_phy_inst
set_param place seed 1
set_param place effort high
place
set_param route effort routability
set_param route fix_hold off
route
fix_hold
update_timing -mode final
report_area -io_info -file $out/final.area
report_qor -step route -file $out/final.qor
report_timing_summary -file $out/final.timing
drc_check -all
exit
