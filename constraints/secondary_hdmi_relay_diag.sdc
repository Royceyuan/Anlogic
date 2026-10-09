create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
# Worst-case 75.1 MHz accepted input, including the main board's 75 MHz.
create_clock -name hdmi_b_pixel -period 13.315 -waveform {0 6.6575} [get_ports {hdmi_b_clk_p}]
derive_clocks
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m}] \
    -group [get_clocks {hdmi_b_pixel u_clock/u_rx_pll.clkc[0] u_clock/u_rx_pll.clkc[1] u_clock/u_rx_pll.clkc[2]}]
# Calibrated serial-input boundary ONLY: the PC data eye has no fixed phase
# relative to a dynamically shifted recovered PLL. These three ports feed
# the first IOL samplers exclusively; no core/parallel path is exempted.
# Eight valid frames qualify a sampling phase. Board tests must establish
# the physical eye margin; a passing core STA is NOT proof of this margin.
set_false_path -from [get_ports {hdmi_b_d0_p hdmi_b_d1_p hdmi_b_d2_p}]
