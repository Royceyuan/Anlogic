create_clock -name clk_50m -period 20 [get_ports clk_50m]
create_clock -name eth_rgmii_rx_clk -period 8 [get_ports eth_rgmii_rx_clk]
derive_clocks
create_generated_clock -name sd_fast -source [get_pins {u_video/u_pll.clkc[0]}] -divide_by 2 [get_ports sd_clk]
set_input_delay -clock sd_fast -max 14.5 [get_ports {sd_cmd sd_dat[*]}]
set_input_delay -clock sd_fast -min 0.0 [get_ports {sd_cmd sd_dat[*]}]
# The enabled SD sampling phases and constraints are unchanged from the 480p baseline.
set_multicycle_path 3 -setup -from [get_ports {sd_cmd sd_dat[*]}]
set_multicycle_path 2 -hold -from [get_ports {sd_cmd sd_dat[*]}]
set_output_delay -clock sd_fast -max 6.0 [get_ports sd_cmd]
set_output_delay -clock sd_fast -min 0.0 [get_ports sd_cmd]
set_multicycle_path 1 -hold -start -to [get_ports sd_cmd]
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m sd_fast u_video/u_pll.clkc[0] u_video/u_pll.clkc[1] u_video/u_pll.clkc[2] u_network/g_original_tx_clock$u_clk_gen/u_pll_0/pll_inst.clkc[0] u_network/g_original_tx_clock$u_clk_gen/u_pll_0/pll_inst.clkc[1] u_network/g_original_tx_clock$u_clk_gen/u_pll_0/pll_inst.clkc[4]}] \
    -group [get_clocks {u_video/u_video_pll.clkc[0] u_video/u_video_pll.clkc[1]}] \
    -group [get_clocks {eth_rgmii_rx_clk u_network/u_rx_pll/pll_inst.clkc[0] u_network/u_rx_pll/pll_inst.clkc[1]}]
