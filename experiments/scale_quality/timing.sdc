# Standalone arithmetic trial, not physical board I/O timing.
create_clock -name trial_clk -period 20 [get_ports clk]
set_input_delay -clock trial_clk 2 [get_ports {start p00* p01* p10* p11* fx* fy*}]
set_output_delay -clock trial_clk 2 [get_ports {busy done pixel*}]
set_false_path -from [get_ports rst_n]
