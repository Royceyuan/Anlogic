# Standalone resource check only; does not alter the product AL/top or bit.
import_device eagle_s20.db -package EG4S20BG256
set result _build_symbol_buffer
file mkdir $result
read_hdl -file {vendor/anlogic_lab6/al_ip/afifo_32_16_256.v src/video/secondary_hdmi_symbol_buffer.v} -top secondary_hdmi_symbol_buffer
create_clock -name receive -period 5.333333 [get_ports write_clk]
create_clock -name output_pixel -period 13.333333 [get_ports read_clk]
optimize_rtl
report_area -file [file join $result symbol_buffer_rtl.area]
optimize_gate -packarea [file join $result symbol_buffer_gate.area]
report_area -file [file join $result symbol_buffer.area]
exit
