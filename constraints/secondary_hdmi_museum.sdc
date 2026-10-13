create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
create_clock -name eth_rgmii_rx_clk -period 8 -waveform {0 4} [get_ports {eth_rgmii_rx_clk}]
create_clock -name hdmi_a_pixel -period 13.315 -waveform {0 6.6575} [get_ports {hdmi_a_clk_p}]
derive_clocks
# Both mux operating modes are timed. The two generated clocks share the
# output pin but retain their respective real source-clock relationships.
create_generated_clock -name tx_local_serial -source [get_pins {u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[1]}] -master_clock {u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[1]} -divide_by 1 -add [get_pins {g_carrier$u_carrier/u_serial_mux.clko}]
create_generated_clock -name tx_external_serial -source [get_pins {u_relay/u_clock/u_rx_pll.clkc[0]}] -master_clock {u_relay/u_clock/u_rx_pll.clkc[0]} -divide_by 1 -add [get_pins {g_carrier$u_carrier/u_serial_mux.clko}]
create_generated_clock -name tx_local_pixel -source [get_pins {u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[0]}] -master_clock {u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[0]} -divide_by 1 -add [get_pins {g_carrier$u_carrier/u_pixel_mux.clko}]
create_generated_clock -name tx_external_pixel -source [get_pins {u_relay/u_clock/u_rx_pll.clkc[2]}] -master_clock {u_relay/u_clock/u_rx_pll.clkc[2]} -divide_by 1 -add [get_pins {g_carrier$u_carrier/u_pixel_mux.clko}]
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m u_terminal/g_shared_clock$u_pll/pll_inst.clkc[0] u_terminal/g_shared_clock$u_pll/pll_inst.clkc[1] u_terminal/g_shared_clock$u_pll/pll_inst.clkc[2] u_terminal/g_shared_clock$u_pll/pll_inst.clkc[3]}] \
    -group [get_clocks {u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[0] u_terminal/u_display/g_video_pll_1280$u_video_pll/pll_inst.clkc[1] tx_local_serial tx_local_pixel}] \
    -group [get_clocks {hdmi_a_pixel u_relay/u_clock/u_rx_pll.clkc[0] u_relay/u_clock/u_rx_pll.clkc[1] u_relay/u_clock/u_rx_pll.clkc[2] tx_external_serial tx_external_pixel}] \
    -group [get_clocks {eth_rgmii_rx_clk u_terminal/u_network/u_rx_pll/pll_inst.clkc[0] u_terminal/u_network/u_rx_pll/pll_inst.clkc[1]}]
# Only the dynamic phase-trained external sampling boundary is excepted.
set_false_path -from [get_ports {hdmi_a_d0_p hdmi_a_d1_p hdmi_a_d2_p}]
# Symbol FIFO read-side first TWO Gray synchronizers use falling pixel edges;
# the binary conversion stays on rising edges. No new CDC timing exclusions.
