onerror {quit -code 1 -f}
set trial [file normalize ./experiments/scale_quality]
file mkdir $trial/../../_build_scale_quality
cd $trial/../../_build_scale_quality
if {![file exists work/_info]} {vlib work}
vmap scale_trial work
vlog -work scale_trial $trial/rgb565_interpolate.v $trial/tb_interpolate.v
vsim -voptargs=+acc -onfinish stop scale_trial.tb_interpolate
run -all
if {[examine -radix unsigned /tb_interpolate/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
