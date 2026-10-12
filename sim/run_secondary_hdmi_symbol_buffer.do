onerror {quit -code 1 -f}
if {[file exists work_hdmi_symbol_buffer]} {vdel -lib work_hdmi_symbol_buffer -all}
vlib work_hdmi_symbol_buffer
vlog -work work_hdmi_symbol_buffer ../vendor/anlogic_lab6/al_ip/afifo_32_16_256.v ../src/video/secondary_hdmi_symbol_buffer.v
vlog -sv -work work_hdmi_symbol_buffer tb_secondary_hdmi_symbol_buffer.v
vsim -c -voptargs=+acc -onfinish stop -lib work_hdmi_symbol_buffer tb_secondary_hdmi_symbol_buffer
run -all
if {[examine -radix unsigned /tb_secondary_hdmi_symbol_buffer/test_pass] != 1} {quit -code 1 -f}
quit -f
