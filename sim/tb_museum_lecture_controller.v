`timescale 1ns / 1ps
`default_nettype none

module tb_museum_lecture_controller;
reg clk = 0;
reg rst_n = 0;
reg enable = 1;
reg confirm = 0;
reg [2:0] selected = 0;
reg load_accept = 0;
reg load_complete = 0;
reg load_error = 0;
wire load_request;
wire [1:0] load_slot;
wire load_detail;
wire [1:0] detail_index;
wire [2:0] artifact;
wire preloading, active, finished;
wire [1:0] display_slot;
wire media_error;

always #5 clk = ~clk;

museum_lecture_controller #(
    .CLOCK_HZ(2), .ART0_PHASE_SECONDS(1), .ART1_PHASE_SECONDS(1),
    .ART2_PHASE_SECONDS(1), .ART3_PHASE_SECONDS(1), .ART4_PHASE_SECONDS(1)
) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .confirm_pulse(confirm),
    .selected_index(selected), .load_request(load_request),
    .load_accept(load_accept), .load_complete(load_complete), .load_error(load_error),
    .load_slot(load_slot), .load_detail(load_detail), .detail_index(detail_index),
    .artifact_index(artifact), .preloading(preloading), .lecture_active(active),
    .lecture_finished(finished), .display_slot(display_slot), .media_error(media_error)
);

task pulse_accept;
begin
    @(negedge clk); load_accept = 1;
    @(negedge clk); load_accept = 0;
end
endtask

task pulse_complete;
begin
    @(negedge clk); load_complete = 1;
    @(negedge clk); load_complete = 0;
end
endtask

integer slot;
initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;
    selected = 3'd4;
    confirm = 1;
    @(negedge clk); confirm = 0;
    for (slot = 0; slot < 4; slot = slot + 1) begin
        if (!load_request || load_slot != slot || load_detail != (slot != 0) ||
            detail_index != slot || artifact != 3'd4)
            $fatal(1, "bad load request slot=%0d", slot);
        pulse_accept;
        pulse_complete;
    end
    if (!active || preloading || display_slot != 0)
        $fatal(1, "lecture did not start after four assets");
    repeat (2) @(negedge clk);
    if (display_slot != 1) $fatal(1, "phase 1 missing");
    repeat (2) @(negedge clk);
    if (display_slot != 2) $fatal(1, "phase 2 missing");
    repeat (2) @(negedge clk);
    if (display_slot != 3) $fatal(1, "phase 3 missing");
    repeat (2) @(negedge clk);
    if (!finished || display_slot != 3) $fatal(1, "lecture finish missing");

    rst_n = 0; repeat (2) @(negedge clk); rst_n = 1;
    selected = 3'd2; confirm = 1; @(negedge clk); confirm = 0;
    pulse_accept;
    @(negedge clk); load_error = 1;
    @(negedge clk); load_error = 0;
    if (!media_error || preloading || active)
        $fatal(1, "missing asset error was not sticky");
    $display("PASS tb_museum_lecture_controller");
    $finish;
end
endmodule

`default_nettype wire
