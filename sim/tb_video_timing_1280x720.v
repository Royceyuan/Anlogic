`timescale 1ns / 1ps

module tb_video_timing_1280x720;
reg clk = 1'b0;
reg rst_n = 1'b0;
wire hs;
wire vs;
wire de;
wire [10:0] x;
wire [9:0] y;
wire frame_tick;
integer seen_active;
integer seen_frame;
integer errors;

always #1 clk = ~clk;

video_timing_programmable_pclk #(
    .H_VISIBLE(1280), .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_VISIBLE(720), .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) dut (
    .clk(clk), .rst_n(rst_n), .hs(hs), .vs(vs), .de(de),
    .x(x), .y(y), .frame_tick(frame_tick)
);

always @(posedge clk) begin
    if (rst_n && de) begin
        seen_active = seen_active + 1;
        if (x > 11'd1279 || y > 10'd719)
            errors = errors + 1;
    end
    if (rst_n && frame_tick) begin
        seen_frame = seen_frame + 1;
        if (seen_frame == 1) begin
            if (seen_active != 1280*720 || errors != 0)
                $display("FAIL: first frame active=%0d errors=%0d", seen_active, errors);
            else
                $display("PASS: 1280x720 timing frame=%0d active=%0d", seen_frame, seen_active);
            $finish;
        end
    end
end

initial begin
    seen_active = 0;
    seen_frame = 0;
    errors = 0;
    #5 rst_n = 1'b1;
    // 1650*750 pixel clocks, plus reset and pipeline margin.
    #3000010;
    $display("FAIL: timeout frame=%0d active=%0d errors=%0d", seen_frame, seen_active, errors);
    $finish;
end
endmodule
