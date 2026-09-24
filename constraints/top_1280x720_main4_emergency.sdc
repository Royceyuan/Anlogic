create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
derive_pll_clocks
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m}] \
    -group [get_clocks {u_top_1280x720_main4/u_sys_pll/pll_inst.clkc[1] u_top_1280x720_main4/u_sys_pll/pll_inst.clkc[2]}] \
    -group [get_clocks {u_top_1280x720_main4/g_video_pll_1280$u_video_pll/pll_inst.clkc[0] u_top_1280x720_main4/g_video_pll_1280$u_video_pll/pll_inst.clkc[1]}]
