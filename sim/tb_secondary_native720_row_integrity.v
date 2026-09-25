`timescale 1ns / 1ps
`default_nettype none

module tb_secondary_native720_row_integrity;
reg clk = 0, rst_n = 0, start = 0;
reg write_req_ack = 0, write_finish = 0;
reg [10:0] pixel_index = 0;
integer word_index = 0;
wire row_ready, write_req, write_en, frame_done, error;
wire [31:0] write_data;
wire [20:0] write_base_addr, write_len;
wire [15:0] expected_even = word_index * 2;
wire [15:0] expected_odd = word_index * 2 + 1;
always #5 clk = ~clk;

bmp_sdram_row_writer #(
    .WIDTH(1280), .HEIGHT(720), .HIRES_WIDTH(1280), .HIRES_HEIGHT(720),
    .BURST_WORDS(16)) dut (
    .clk(clk), .rst_n(rst_n), .start(start), .hires_frame(1'b1),
    .row_valid(pixel_index < 1280), .row_index(10'd3),
    .row_pixel({5'd0, pixel_index}), .row_last(pixel_index == 1279),
    .row_ready(row_ready), .frame_base_addr(21'd921600),
    .overview_base_addr(21'd0), .overview_frame_index(4'hf),
    .write_req(write_req), .write_req_ack(write_req_ack),
    .write_en(write_en), .write_data(write_data),
    .write_base_addr(write_base_addr), .write_len(write_len),
    .write_fifo_full(1'b0), .write_finish(write_finish),
    .frame_done(frame_done), .error(error)
);

always @(posedge clk) begin
    if (!rst_n || start) begin
        pixel_index <= 0;
        word_index <= 0;
        write_req_ack <= 0;
        write_finish <= 0;
    end else begin
        write_req_ack <= write_req;
        write_finish <= write_en && (word_index % 16 == 15);
        if (row_ready && pixel_index < 1280)
            pixel_index <= pixel_index + 1'b1;
        if (write_en) begin
            if (write_len != 16 ||
                write_base_addr != 21'd921600 + 3 * 640 + (word_index / 16) * 16 ||
                write_data !== {expected_even, expected_odd})
                $fatal(1, "720p row mismatch at word %0d: base=%0d data=%h",
                       word_index, write_base_addr, write_data);
            word_index <= word_index + 1;
        end
    end
end

initial begin
    repeat (3) @(negedge clk);
    rst_n = 1;
    start = 1;
    @(negedge clk); start = 0;
    wait (word_index == 640);
    repeat (3) @(negedge clk);
    if (error || pixel_index != 1280) $fatal(1, "row did not complete cleanly");
    $display("PASS: all 640 32-bit words of a native 720p row, across 40 bursts");
    $finish;
end
initial begin
    #1000000;
    $fatal(1, "native 720p row timeout at word %0d", word_index);
end
endmodule

`default_nettype wire
