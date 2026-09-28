create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
create_clock -name eth_rgmii_rx_clk -period 8 -waveform {0 4} [get_ports {eth_rgmii_rx_clk}]
derive_clocks
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m}] \
    -group [get_clocks {u_display/u_sys_pll/pll_inst.clkc[1] u_display/u_sys_pll/pll_inst.clkc[2]}] \
    -group [get_clocks {u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[0] u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[1]}] \
    -group [get_clocks {u_network/u_clk_gen/u_pll_0/pll_inst.clkc[1]}] \
    -group [get_clocks {eth_rgmii_rx_clk u_network/u_rx_pll/pll_inst.clkc[0] u_network/u_rx_pll/pll_inst.clkc[1]}]
