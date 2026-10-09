create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
# These external, slowly changing lines feed two-stage input synchronizers.
# No synchronous timing contract with the cable; internal paths remain checked.
set_false_path -from [get_ports {key1_n hdmi_a_hpd hdmi_a_scl hdmi_a_sda hdmi_b_scl hdmi_b_sda}]
