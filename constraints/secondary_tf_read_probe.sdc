create_clock -name clk_50m -period 20 [get_ports clk_50m]
derive_clocks
# Read sampling is enabled only at SD rising edges. The fastest card clock is
# clk100/2; its default/init modes are slower. Keep card-return timing explicit.
create_generated_clock -name sd_fast -source [get_pins {u_pll.clkc[0]}] -divide_by 2 [get_ports sd_clk]
set_input_delay -clock sd_fast -max 14.5 [get_ports {sd_cmd sd_dat[*]}]
set_input_delay -clock sd_fast -min 0.0 [get_ports {sd_cmd sd_dat[*]}]
# Card launches at forwarded rising edge N. Enabled negative-edge input
# sampling is at core edge N+25ns in the fastest mode (three 100MHz half-shifted
# setup edges); the intervening negative edge is not enabled.
set_multicycle_path 3 -setup -from [get_ports {sd_cmd sd_dat[*]}]
set_multicycle_path 2 -hold -from [get_ports {sd_cmd sd_dat[*]}]
set_output_delay -clock sd_fast -max 6.0 [get_ports sd_cmd]
set_output_delay -clock sd_fast -min 0.0 [get_ports sd_cmd]
# CMD changes only at the SD falling edge: the next possible update is the
# intervening core edge, 10ns after the receiving SD rising edge.
set_multicycle_path 1 -hold -start -to [get_ports sd_cmd]
