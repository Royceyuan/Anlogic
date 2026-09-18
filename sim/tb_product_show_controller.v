`timescale 1ns / 1ps

module tb_product_show_controller;
reg clk = 1'b0;
reg rst_n = 1'b0;
reg enable = 1'b0;
reg key_pause = 1'b0;
reg key_previous = 1'b0;
reg key_next = 1'b0;
wire [3:0] image_index, product_index;
wire [2:0] state;
wire pause_flag;
wire [1:0] transition_context, demo_step;

product_show_controller #(
    .VIDEO_HOLD_CYCLES(3), .DETAIL_HOLD_CYCLES(3),
    .TRANSITION_HOLD_CYCLES(2), .PRODUCT_COUNT(2)
) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .key_pause(key_pause),
    .key_previous(key_previous), .key_next(key_next),
    .image_index(image_index), .product_index(product_index), .state(state),
    .pause_flag(pause_flag), .transition_context(transition_context),
    .demo_step(demo_step)
);

always #5 clk = ~clk;

task pulse_pause;
    begin
        @(negedge clk); key_pause = 1'b1;
        @(negedge clk); key_pause = 1'b0;
    end
endtask

task pulse_previous;
    begin
        @(negedge clk); key_previous = 1'b1;
        @(negedge clk); key_previous = 1'b0;
    end
endtask

task pulse_next;
    begin
        @(negedge clk); key_next = 1'b1;
        @(negedge clk); key_next = 1'b0;
    end
endtask

integer cycles;
reg [7:0] seen_states;
reg [3:0] held_image;

initial begin
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;

    cycles = 0;
    seen_states = 8'd0;
    while (cycles < 80 && !(product_index == 1 && state == 3'd1)) begin
        @(posedge clk); #1;
        seen_states[state] = 1'b1;
        cycles = cycles + 1;
    end
    if (seen_states != 8'hff || product_index != 1)
        $fatal(1, "automatic FSM cycle failed states=%h product=%0d", seen_states, product_index);

    while (state != 3'd1) begin @(posedge clk); #1; end
    pulse_pause;
    if (!pause_flag) $fatal(1, "pause key failed");
    held_image = image_index;
    repeat (10) @(posedge clk);
    if (state != 3'd1 || image_index != held_image)
        $fatal(1, "paused video advanced");
    pulse_pause;
    if (pause_flag) $fatal(1, "resume key failed");

    pulse_next;
    if (product_index != 0 || state != 3'd6 || transition_context != 2'd2)
        $fatal(1, "next product failed");
    pulse_previous;
    if (product_index != 1 || state != 3'd6)
        $fatal(1, "previous product failed");

    $display("PASS product_show_controller full cycle and keys");
    $finish;
end

endmodule
