create_clock -name SYS_CLK -period 20 -waveform {0 10} [get_ports {SYS_CLK}]
create_clock -name HDMI_CLK_IN -period 13.468 -waveform {0 6.734} [get_ports {HDMI_CLK_P}]
derive_clocks
set_clock_groups -asynchronous \
    -group [get_clocks {SYS_CLK}] \
    -group [get_clocks {HDMI_CLK_IN u1_rx/u1_pll/pll_inst.clkc[0] u1_rx/u1_pll/pll_inst.clkc[1] u1_rx/u1_pll/pll_inst.clkc[2]}]
# Official dynamic-phase first IOL sampling boundary; board eye remains unproven.
# All internal paths, including failing serial bitslip paths, remain checked.
set_false_path -from [get_ports {HDMI_D0_P HDMI_D1_P HDMI_D2_P}]
set_false_path -from [get_ports {scl sda}]
