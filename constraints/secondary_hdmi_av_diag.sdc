create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
# Worst-case accepted input; the PC's 74.25/74.176 MHz is below this bound.
create_clock -name hdmi_a_pixel -period 13.315 -waveform {0 6.6575} [get_ports {hdmi_a_clk_p}]
derive_clocks
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m}] \
    -group [get_clocks {hdmi_a_pixel u_relay/u_clock/u_rx_pll.clkc[0] u_relay/u_clock/u_rx_pll.clkc[1] u_relay/u_clock/u_rx_pll.clkc[2]}]
# Dynamic-phase first IOL sampling ONLY. Board input eye margin is unproven.
set_false_path -from [get_ports {hdmi_a_d0_p hdmi_a_d1_p hdmi_a_d2_p}]
