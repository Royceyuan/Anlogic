# Standalone elaboration/resource check. No product P&R/bit is generated.
import_device eagle_s20.db -package EG4S20BG256
set result _build_hdmi_handoff
file mkdir $result
set probe handoff
if {[info exists ::env(SECONDARY_HDMI_PROBE)]} {set probe $::env(SECONDARY_HDMI_PROBE)}
if {$probe eq "handoff"} {
    read_hdl -file src/video/secondary_hdmi_frame_handoff.v -top secondary_hdmi_frame_handoff
    create_clock -name output_pixel -period 13.333333 [get_ports clk]
} elseif {$probe eq "serializer"} {
    read_hdl -file src/video/secondary_hdmi_symbol_pairs.v -top secondary_hdmi_symbol_pairs
    create_clock -name output_pixel -period 13.333333 [get_ports pixel_clk]
    create_clock -name output_serial -period 2.666667 [get_ports serial_clk]
} else {error "SECONDARY_HDMI_PROBE must be handoff or serializer"}
# One design per TD process. Re-reading an optimized design then creating
# clocks can leave stale port objects in this TD version.
optimize_rtl
optimize_gate -packarea [file join $result ${probe}_gate.area]
report_area -file [file join $result ${probe}.area]
exit
