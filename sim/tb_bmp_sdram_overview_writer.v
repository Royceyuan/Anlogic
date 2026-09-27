`timescale 1ns / 1ps

module tb_bmp_sdram_overview_writer;
parameter integer OVERVIEW_BRAM = 0;
localparam integer WIDTH = 6;
localparam integer HEIGHT = 2;
localparam integer FRAME_BASE = 20;
localparam integer OVERVIEW_BASE = 100;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg start = 1'b0;
reg row_valid = 1'b0;
reg [1:0] row_index = 2'd0;
reg [15:0] row_pixel = 16'd0;
reg row_last = 1'b0;
wire row_ready;
reg [3:0] overview_frame_index = 4'd1;
wire write_req;
wire write_en;
wire [31:0] write_data;
wire [7:0] write_base_addr;
wire [7:0] write_len;
reg write_finish = 1'b0;
wire frame_done;
wire error;

reg [31:0] mem [0:127];
reg transaction_active = 1'b0;
reg [7:0] transaction_word = 8'd0;
integer i;

assign write_req_ack = write_req;
assign write_fifo_full = 1'b0;

bmp_sdram_row_writer #(
    .WIDTH(WIDTH), .HEIGHT(HEIGHT), .ROW_BITS(2), .ADDR_BITS(8),
    .WORDS_PER_ROW(3), .BURST_WORDS(1),
    .OVERVIEW_ENABLE(1), .OVERVIEW_BRAM(OVERVIEW_BRAM), .OVERVIEW_FRAME_COUNT(3),
    .OVERVIEW_PANEL_WIDTH(2),
    .OVERVIEW_CROP_X0_0(0), .OVERVIEW_CROP_X0_1(2),
    .OVERVIEW_CROP_X0_2(4), .OVERVIEW_CROP_X0_3(0),
    .OVERVIEW_CROP_X0_4(0)
) dut (
    .clk(clk), .rst_n(rst_n), .start(start),
    .row_valid(row_valid), .row_index(row_index), .row_pixel(row_pixel),
    .row_last(row_last), .row_ready(row_ready),
    .frame_base_addr(8'd20), .overview_base_addr(8'd100),
    .overview_frame_index(overview_frame_index),
    .write_req(write_req), .write_req_ack(write_req_ack),
    .write_en(write_en), .write_data(write_data),
    .write_base_addr(write_base_addr), .write_len(write_len),
    .write_fifo_full(write_fifo_full), .write_finish(write_finish),
    .abort(1'b0), .abort_done(),
    .frame_done(frame_done), .error(error)
);

always #10 clk = ~clk;

always @(posedge clk) begin
    write_finish <= 1'b0;
    if (write_req && !transaction_active) begin
        transaction_active <= 1'b1;
        transaction_word <= 8'd0;
    end
    if (transaction_active && write_en) begin
        mem[write_base_addr + transaction_word] <= write_data;
        if (transaction_word == write_len - 1) begin
            transaction_active <= 1'b0;
            write_finish <= 1'b1;
        end else begin
            transaction_word <= transaction_word + 1'b1;
        end
    end
end

task send_row;
    input [1:0] row_value;
    integer col;
    begin
        col = 0;
        while (col < WIDTH) begin
            @(negedge clk);
            row_index = row_value;
            row_pixel = row_value * 16 + col;
            row_last = (col == WIDTH - 1);
            row_valid = 1'b1;
            #1;
            while (!row_ready) begin
                @(negedge clk);
                #1;
            end
            @(posedge clk);
            col = col + 1;
        end
        @(negedge clk);
        row_valid = 1'b0;
        row_last = 1'b0;
    end
endtask

initial begin
    for (i = 0; i < 128; i = i + 1)
        mem[i] = 32'hdeadbeef;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk); start = 1'b1;
    @(negedge clk); start = 1'b0;

    send_row(0);
    send_row(1);
    wait (frame_done || error);
    if (error)
        $fatal(1, "overview writer reported error");

    if (mem[20] !== 32'h00000001 || mem[21] !== 32'h00020003 ||
        mem[22] !== 32'h00040005 || mem[23] !== 32'h00100011 ||
        mem[24] !== 32'h00120013 || mem[25] !== 32'h00140015)
        $fatal(1, "full-frame write mismatch");

    if (mem[101] !== 32'h00020003 || mem[104] !== 32'h00120013)
        $fatal(1, "overview crop write mismatch: %h %h", mem[101], mem[104]);
    if (mem[100] !== 32'hdeadbeef || mem[102] !== 32'hdeadbeef ||
        mem[103] !== 32'hdeadbeef || mem[105] !== 32'hdeadbeef)
        $fatal(1, "overview writer touched another panel");

    $display("PASS bmp_sdram_overview_writer full frame plus horizontal crop");
    $finish;
end

initial begin
    #500000;
    $fatal(1, "timeout state=%0d phase=%0d row=%0d pixel=%0d overview_pixel=%0d req=%0d active=%0d",
           dut.state, dut.overview_phase, dut.active_row, dut.row_pixel_index,
           dut.overview_pixel_index, write_req, transaction_active);
end

endmodule
