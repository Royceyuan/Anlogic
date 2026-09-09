`timescale 1ns/1ps

module tb_frame_fifo_read_partial_burst #(
    parameter integer BASE = 1000,
    parameter integer LENGTH = 129600
);

reg clk = 1'b0;
reg rst = 1'b1;
reg read_req = 1'b0;
reg sdr_rd_en = 1'b0;
wire app_rd_en;
wire [20:0] app_rd_addr;
wire read_req_ack;
integer request_count = 0;
integer base_count = 0;

always #5 clk = ~clk;

frame_fifo_read #(
    .ADDR_BITS(21), .BURST_BITS(9), .FIFO_DEPTH(512),
    .BURST_SIZE(128), .LOOP_ENABLE(1)
) dut (
    .rst(rst), .mem_clk(clk), .Sdr_init_done(1'b1),
    .Sdr_init_ref_vld(1'b1), .Sdr_busy(1'b0), .Sdr_rd_en(sdr_rd_en),
    .App_wr_busy(1'b0), .O_rd_busy(), .App_rd_en(app_rd_en),
    .App_rd_addr(app_rd_addr), .read_req(read_req),
    .read_req_ack(read_req_ack), .read_finish(),
    .read_addr_0(BASE[20:0]), .read_addr_1(21'd0),
    .read_addr_2(21'd0), .read_addr_3(21'd0),
    .read_addr_index(2'd0), .read_len(LENGTH[20:0]),
    .fifo_aclr(), .wrusedw(10'd0)
);

always @(posedge clk) begin
    sdr_rd_en <= app_rd_en;
    if (read_req_ack)
        read_req <= 1'b0;
    if (app_rd_en) begin
        request_count <= request_count + 1;
        if (app_rd_addr == BASE[20:0]) begin
            base_count <= base_count + 1;
            if (base_count == 1) begin
                if (request_count != LENGTH)
                    $fatal(1, "loop restarted after %0d words, expected %0d",
                           request_count, LENGTH);
                $display("PASS partial final burst loops after exactly %0d words", LENGTH);
                $finish;
            end
        end
    end
end

initial begin
    repeat (4) @(posedge clk);
    rst <= 1'b0;
    @(posedge clk);
    read_req <= 1'b1;
    repeat (400000) @(posedge clk);
    $fatal(1, "timeout waiting for second loop");
end
endmodule
