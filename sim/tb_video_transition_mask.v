`timescale 1ns / 1ps

module tb_video_transition_mask;
    reg [23:0] rgb_in;
    reg de;
    reg [10:0] x;
    reg [9:0] y;
    reg [2:0] mode;
    reg [5:0] progress;
    reg enable;
    wire [23:0] rgb_out;
    integer m;

    video_transition_mask u_dut (
        .rgb_in(rgb_in), .de(de), .x(x), .y(y), .mode(mode),
        .progress(progress),
        .enable(enable), .rgb_out(rgb_out)
    );

    task expect_rgb;
        input [23:0] expected;
        begin
            #1;
            if (rgb_out !== expected) begin
                $display("FAIL mode=%0d p=%0d x=%0d y=%0d got=%h exp=%h",
                         mode, progress, x, y, rgb_out, expected);
                $fatal;
            end
        end
    endtask

    initial begin
        rgb_in = 24'h123456;
        de = 1'b1;
        enable = 1'b1;

        // Fade and reserved mode are pass-through; blanking is not altered.
        mode = 3'b000; progress = 5'd8; x = 11'd700; y = 10'd500; expect_rgb(rgb_in);
        mode = 3'b111; progress = 5'd8; expect_rgb(rgb_in);
        mode = 3'b001; de = 1'b0; expect_rgb(rgb_in); de = 1'b1;

        // Left/top wipes at start and completion.
        mode = 3'b001; progress = 5'd0; x = 11'd100; y = 10'd10; expect_rgb(24'h0);
        x = 11'd10; expect_rgb(rgb_in);
        progress = 6'd36; x = 11'd799; expect_rgb(rgb_in);
        mode = 3'b010; progress = 5'd0; x = 11'd10; y = 10'd100; expect_rgb(24'h0);
        y = 10'd10; expect_rgb(rgb_in);

        // Horizontal blinds open from the centre of each of four bands.
        mode = 3'b011; progress = 6'd0; x = 11'd100; y = 10'd75; expect_rgb(rgb_in);
        y = 10'd0; expect_rgb(24'h0);
        // Checker blocks begin sparse and complete after the longer cadence.
        mode = 3'b100; progress = 5'd0; x = 11'd768; y = 10'd576; expect_rgb(24'h0);
        progress = 6'd60; expect_rgb(rgb_in);
        mode = 3'b101; progress = 5'd0; x = 11'd400; y = 10'd300; expect_rgb(rgb_in);
        x = 11'd0; y = 10'd0; expect_rgb(24'h0);
        mode = 3'b110; progress = 5'd0; x = 11'd700; y = 10'd500; expect_rgb(24'h0);
        progress = 6'd36; expect_rgb(rgb_in);

        // Every legal selector must produce a known RGB value.
        for (m = 0; m < 8; m = m + 1) begin
            mode = m[2:0]; progress = 5'd10; x = 11'd321; y = 10'd241;
            #1;
            if (^rgb_out === 1'bx) begin
                $display("FAIL unknown output mode=%0d", m);
                $fatal;
            end
        end
        $display("PASS: video_transition_mask all modes");
        $finish;
    end
endmodule
