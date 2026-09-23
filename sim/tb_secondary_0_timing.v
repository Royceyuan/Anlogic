`timescale 1ns / 1ps
`default_nettype none

module tb_secondary_0_timing;
reg clk = 1'b0;
reg rst_n = 1'b0;
wire hs, vs, de, frame_tick;
wire [10:0] x;
wire [9:0] y;
wire [23:0] rgb;
integer h = 0;
integer v = 0;
integer active_pixels = 0;
integer ticks = 0;
integer checked_cycles = 0;

always #5 clk = ~clk;

video_timing_1280x720_pclk dut (
    .clk(clk), .rst_n(rst_n), .hs(hs), .vs(vs), .de(de),
    .x(x), .y(y), .frame_tick(frame_tick)
);
hdmi_1280x720_pattern pattern (
    .de(de), .x(x), .y(y), .rgb(rgb)
);

task fail;
    input [255:0] reason;
    begin
        $display("FAIL: %0s h=%0d v=%0d x=%0d y=%0d", reason, h, v, x, y);
        $fatal(1);
    end
endtask

always @(posedge clk) begin
    if (rst_n) begin
        #1;
        if (x !== h || y !== v) fail("pixel position");
        if (de !== ((h < 1280) && (v < 720))) fail("active region");
        if (hs !== !((h >= 1390) && (h < 1430))) fail("horizontal sync");
        if (vs !== !((v >= 725) && (v < 730))) fail("vertical sync");
        if (frame_tick !== ((h == 1649) && (v == 749))) fail("frame tick");
        if (!de && rgb !== 24'h000000) fail("blanking color");
        if (de && (h == 0 || h == 639 || h == 640 || h == 1279 || v == 359 || v == 360) &&
            rgb !== 24'hFFFFFF) fail("alignment line");
        if (de) active_pixels = active_pixels + 1;
        checked_cycles = checked_cycles + 1;
        if (h == 1649) begin
            h = 0;
            if (v == 749) begin
                v = 0;
                ticks = ticks + 1;
                if (active_pixels != ticks * 1280 * 720) fail("active pixel count");
                if (ticks == 2) begin
                    $display("PASS: SECONDARY-0 1650x750, active=1280x720, frame ticks=2, checked=%0d", checked_cycles);
                    $finish;
                end
            end else v = v + 1;
        end else h = h + 1;
    end
end

initial begin
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    #25000000;
    fail("timeout");
end
endmodule

`default_nettype wire
