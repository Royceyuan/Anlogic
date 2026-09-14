`timescale 1ns / 1ps

module tb_video_transition_mask;
    reg [23:0] rgb_in;
    reg de;
    reg [10:0] x;
    reg [9:0] y;
    reg [2:0] mode;
    reg [5:0] progress;
    reg closing;
    reg enable;
    wire [23:0] rgb_out;
    reg [4:0] fade_level;
    wire [23:0] fade_rgb;
    integer m;

    video_transition_mask #(.VIDEO_W(1280), .VIDEO_H(720)) u_dut (
        .rgb_in(rgb_in), .de(de), .x(x), .y(y), .mode(mode),
        .progress(progress), .closing(closing),
        .enable(enable), .rgb_out(rgb_out)
    );
    video_fade u_fade (
        .rgb_in(rgb_in), .level(fade_level), .rgb_out(fade_rgb)
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
        closing = 1'b0;
        fade_level = 5'd0;

        #1;
        if (fade_rgb !== 24'h000000)
            $fatal(1, "fade midpoint is not black: %h", fade_rgb);
        fade_level = 5'd16;
        #1;
        if (fade_rgb !== rgb_in)
            $fatal(1, "fade completion changed RGB: %h", fade_rgb);

        // Fade is handled by video_fade; blanking and disabled masks pass.
        mode = 3'b000; progress = 6'd8; x = 11'd700; y = 10'd500; expect_rgb(rgb_in);
        mode = 3'b001; de = 1'b0; expect_rgb(rgb_in); de = 1'b1;
        enable = 1'b0; expect_rgb(rgb_in); enable = 1'b1;

        // Every geometry primitive closes to full black and starts the new
        // source at full black before revealing it.
        for (m = 1; m <= 3; m = m + 1) begin
            mode = m[2:0]; x = 11'd640; y = 10'd360;
            closing = 1'b1; progress = 6'd0; expect_rgb(rgb_in);
            progress = 6'd16; expect_rgb(24'h0);
            closing = 1'b0; progress = 6'd16; expect_rgb(24'h0);
            progress = 6'd32; expect_rgb(rgb_in);
        end

        // Mid-progress geometry remains visibly distinct.
        closing = 1'b0; progress = 6'd24;
        mode = 3'b001; x = 11'd100; y = 10'd100; expect_rgb(rgb_in);
        x = 11'd1000; expect_rgb(24'h0);
        mode = 3'b010; x = 11'd640; y = 10'd100; expect_rgb(rgb_in);
        x = 11'd100; expect_rgb(24'h0);
        mode = 3'b011; x = 11'd640; y = 10'd360; expect_rgb(rgb_in);
        x = 11'd100; y = 10'd100; expect_rgb(24'h0);

        // Every legal selector must produce a known RGB value.
        for (m = 0; m < 4; m = m + 1) begin
            mode = m[2:0]; progress = 5'd10; x = 11'd321; y = 10'd241;
            #1;
            if (^rgb_out === 1'bx) begin
                $display("FAIL unknown output mode=%0d", m);
                $fatal;
            end
        end
        $display("PASS: phase3 transition mask close/midpoint/reveal");
        $finish;
    end
endmodule
