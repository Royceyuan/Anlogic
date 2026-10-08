create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
create_clock -name eth_rgmii_rx_clk -period 8 -waveform {0 4} [get_ports {eth_rgmii_rx_clk}]
derive_clocks
# The common PLL and clk_50m are related: do not mask their timing as async.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m u_terminal/g_shared_clock$u_pll/pll_inst.clkc[0] u_terminal/g_shared_clock$u_pll/pll_inst.clkc[1] u_terminal/g_shared_clock$u_pll/pll_inst.clkc[2] u_terminal/g_shared_clock$u_pll/pll_inst.clkc[3]}] \
    -group [get_clocks {u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[0] u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[1]}] \
    -group [get_clocks {eth_rgmii_rx_clk u_terminal/u_network/u_rx_pll/pll_inst.clkc[0] u_terminal/u_network/u_rx_pll/pll_inst.clkc[1]}]
