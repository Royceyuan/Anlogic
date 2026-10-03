onerror {quit -code 1 -f}
set root [file normalize ..]
source $root/experiments/scale_quality/prepare_horizontal.tcl
set out $root/_build_horizontal_interpolation/sim
file mkdir $out
# Reuse the committed FAT32 disk/SDRAM model without editing the user's dirty
# bench. Fail if its known anchors disappear rather than silently testing NN.
quietly set bench [string map {\r {}} [exec git show HEAD:sim/tb_fat32_bmp_adaptive_loader.v]]
set anchors [list {parameter integer IMAGE_W = 640,} {.ADAPTIVE_BMP(ADAPTIVE_MODE),} {reg clk = 1'b0;} {expected_pixel = {red[7:3], green[7:2], blue[7:3]};} {$display("Adaptive BMP: PASS source=}]
foreach anchor $anchors {
    if {[string first $anchor $bench] < 0} {error "Missing adaptive bench anchor: $anchor"}
}
quietly set helper {
function [15:0] horizontal_expected;
    input integer xx, yy, fit_index, fitted_width;
    integer right_x, fraction, r0,r1,g0,g1,b0,b1;
    reg [7:0] value;
    begin
        right_x = (xx+1 < SOURCE_W) ? xx+1 : xx;
        fraction = HORIZONTAL_TRIAL_MODE ? ((fit_index*SOURCE_W)%fitted_width)*256/fitted_width : 0;
        value=source_red(xx,yy); r0=value>>3;
        value=source_red(right_x,yy); r1=value>>3;
        value=source_green(xx,yy); g0=value>>2;
        value=source_green(right_x,yy); g1=value>>2;
        value=source_blue(xx,yy); b0=value>>3;
        value=source_blue(right_x,yy); b1=value>>3;
        horizontal_expected = (((r0*(256-fraction)+r1*fraction+128)/256)<<11) |
                              (((g0*(256-fraction)+g1*fraction+128)/256)<<5) |
                               ((b0*(256-fraction)+b1*fraction+128)/256);
    end
endfunction
}
quietly set bench [string map [list \
    {parameter integer IMAGE_W = 640,} {parameter integer HORIZONTAL_TRIAL_MODE=1, parameter integer ABORT_STAGE=-1, parameter integer IMAGE_W = 640,} \
    {.ADAPTIVE_BMP(ADAPTIVE_MODE),} {.ADAPTIVE_BMP(ADAPTIVE_MODE), .ADAPTIVE_HORIZONTAL_INTERPOLATION(HORIZONTAL_TRIAL_MODE),} \
    {reg clk = 1'b0;} {reg test_pass=0; reg clk = 1'b0;} \
    {.overview_base_addr(21'd0), .overview_frame_index(4'd0),} {.overview_base_addr(21'd0), .overview_frame_index(4'd0), .abort(1'b0), .abort_done(),} \
    {: y[7:0];} {: (17*x+7*y)&8'hff;} \
    {function [15:0] expected_pixel;} "$helper\nfunction \[15:0\] expected_pixel;" \
    {expected_pixel = {red[7:3], green[7:2], blue[7:3]};} {expected_pixel = horizontal_expected(expected_x,expected_y,fit_x,fit_w);} \
    {$display("Adaptive BMP: PASS source=} {test_pass=1; $display("Adaptive BMP: PASS source=}] $bench]
quietly set abort_test {
generate if (HORIZONTAL_TRIAL_MODE) begin : check_stable_inputs
    reg [15:0] left_sample, right_sample;
    reg [7:0] fraction_sample;
    always @(posedge clk) if (rst_n) begin
        if (dut.state==21) begin
            left_sample<=dut.adapt_left_pixel;
            right_sample<=dut.adapt_row_mem_read;
            fraction_sample<=dut.adapt_fraction;
        end
        if (dut.g_horizontal_interpolation.u_interpolate.busy &&
            (dut.adapt_left_pixel!==left_sample ||
             dut.adapt_row_mem_read!==right_sample ||
             dut.adapt_fraction!==fraction_sample))
            $fatal(1,"Loader changed an interpolation input while busy");
    end
end endgenerate
initial if (ABORT_STAGE>=0) begin
    wait(dut.state==ABORT_STAGE);
    @(negedge clk); rst_n=0;
    repeat(4) @(negedge clk);
    written=0; write_count=0; error_count=0; missing_count=0;
    frame_write_count=0; frame_error_count=0; frame_fake_count=0;
    frame_fake_base=0; frame_req_seen=0;
    rst_n=1;
    repeat(3) @(negedge clk); load_start=1;
    @(negedge clk); load_start=0;
end
}
quietly set bench [string map [list endmodule "$abort_test\nendmodule"] $bench]
set fd [open $out/tb_horizontal_loader.v w]; puts $fd $bench; close $fd
cd $out
if {![file exists work/_info]} {vlib work}
vmap horizontal_trial work
vlog +define+SIM -work horizontal_trial $root/experiments/scale_quality/rgb565_interpolate.v \
    $root/src/storage/al_dp_ram16.v $root/src/storage/adaptive_row_ram.v \
    $rtl/src/storage/fat32_image_loader.v $root/src/storage/bmp_row_buffer.v \
    $root/src/storage/rgb565_stream_packer_ready.v $root/src/storage/bmp_sdram_block_writer.v \
    $root/src/storage/bmp_sdram_row_writer.v $out/tb_horizontal_loader.v
foreach mode {0 1} {
foreach ram {9K 32K} {
foreach dims {{65 47} {31 79} {96 72} {16 16} {17 29} {67 48}} {
foreach orientation {0 1} {
    vsim -voptargs=+acc -onfinish stop horizontal_trial.tb_fat32_bmp_adaptive_loader \
        -gHORIZONTAL_TRIAL_MODE=$mode -gIMAGE_W=64 -gIMAGE_H=48 \
        -gSOURCE_W=[lindex $dims 0] -gSOURCE_H=[lindex $dims 1] -gTOP_DOWN=$orientation \
        -gADAPTIVE_RAM_IMPLEMENT=$ram
    run -all
    if {[examine -radix unsigned /tb_fat32_bmp_adaptive_loader/test_pass] != 1} {quit -code 1 -f}
    quit -sim
}
}
}
}
foreach stage {20 21 22 23} {
    vsim -voptargs=+acc -onfinish stop horizontal_trial.tb_fat32_bmp_adaptive_loader \
        -gIMAGE_W=64 -gIMAGE_H=48 -gSOURCE_W=65 -gSOURCE_H=47 -gABORT_STAGE=$stage
    run -all
    if {[examine -radix unsigned /tb_fat32_bmp_adaptive_loader/test_pass] != 1} {quit -code 1 -f}
    puts "PASS interpolation abort/reload stage=$stage"
    quit -sim
}
vsim -voptargs=+acc -onfinish stop horizontal_trial.tb_fat32_bmp_adaptive_loader \
    -gIMAGE_W=960 -gIMAGE_H=540 -gIMAGE_ADDR_BITS=19 -gSOURCE_W=1919 -gSOURCE_H=1080 \
    -gTOP_DOWN=0 -gBMP_MAX_WIDTH=1920 -gBMP_MAX_HEIGHT=1080 -gDISK_BYTES=8388608 \
    -gRESOURCE_OPT_CONSTANT_MULT=1 -gADAPTIVE_RAM_IMPLEMENT=32K
run -all
if {[examine -radix unsigned /tb_fat32_bmp_adaptive_loader/test_pass] != 1} {quit -code 1 -f}
puts "PASS horizontal integration: 48 geometry/RAM/on-off cases, 4 abort/reloads, 1919x1080 full row/SDRAM path"
quit -code 0 -f
