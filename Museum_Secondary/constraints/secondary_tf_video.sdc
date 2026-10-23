create_clock -name clk_50m -period 20 [get_ports clk_50m]
derive_clocks
create_generated_clock -name sd_fast -source [get_pins {u_pll.clkc[0]}] -divide_by 2 [get_ports sd_clk]
set_input_delay -clock sd_fast -max 14.5 [get_ports {sd_cmd sd_dat[*]}]
set_input_delay -clock sd_fast -min 0.0 [get_ports {sd_cmd sd_dat[*]}]
# Same enabled input-sampling edges as the board-passed gap8 probe.
set_multicycle_path 3 -setup -from [get_ports {sd_cmd sd_dat[*]}]
set_multicycle_path 2 -hold -from [get_ports {sd_cmd sd_dat[*]}]
set_output_delay -clock sd_fast -max 6.0 [get_ports sd_cmd]
set_output_delay -clock sd_fast -min 0.0 [get_ports sd_cmd]
set_multicycle_path 1 -hold -start -to [get_ports sd_cmd]
# Ownership toggles and bundled stable slot values cross via two registers;
# SDRAM queues retain the existing Gray-pointer asynchronous FIFOs.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m u_pll.clkc[0] u_pll.clkc[1] u_pll.clkc[2] sd_fast}] \
    -group [get_clocks {u_video_pll.clkc[0] u_video_pll.clkc[1]}]
