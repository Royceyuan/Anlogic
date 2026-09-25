`timescale 1ns/1ps
`default_nettype none

// Exercises the diagnostic producer/comparator through the production frame
// controllers and async FIFOs with an ideal single-cycle SDRAM response.
module tb_secondary_fullframe_rw_path;
localparam [20:0] WORDS = 21'd1280;
reg clk = 0, rst = 1;
always #10 clk = ~clk;
reg write_req = 0, read_req = 0, read_active = 0;
reg [10:0] write_count = 0, read_count = 0;
reg [2:0] state = 0;
reg [5:0] settle = 0;
reg sdr_rd_en = 0;
reg [31:0] sdr_rd_dout = 0;
reg [31:0] mem [0:WORDS-1];
wire write_req_ack, write_finish, write_fifo_full;
wire read_req_ack, read_fifo_valid, read_fifo_empty;
wire app_wr_en, app_rd_en;
wire [20:0] app_wr_addr, app_rd_addr;
wire [31:0] app_wr_din, read_data;
wire [3:0] app_wr_dm;
wire write_en = state == 3 && !write_fifo_full;
wire [31:0] write_data = 32'hA5000000 + write_count;

frame_read_write #(
    .BURST_SIZE(128), .WRITE_BURST_SIZE(16),
    .READ_BURST_SIZE(128), .READ_LOOP(0)
) dut (
    .rst(rst), .mem_clk(clk), .Sdr_init_done(1'b1),
    .Sdr_init_ref_vld(1'b1), .Sdr_busy(1'b0),
    .App_rd_en(app_rd_en), .App_rd_addr(app_rd_addr),
    .Sdr_rd_en(sdr_rd_en), .Sdr_rd_dout(sdr_rd_dout),
    .read_clk(clk), .read_req(read_req), .read_req_ack(read_req_ack),
    .read_finish(), .read_fifo_valid(read_fifo_valid),
    .read_fifo_empty(read_fifo_empty),
    .read_addr_0(21'd0), .read_addr_1(21'd0),
    .read_addr_2(21'd0), .read_addr_3(21'd0),
    .read_addr_index(2'd0), .read_len(WORDS),
    .read_en(read_active && !read_fifo_empty), .read_data(read_data),
    .App_wr_en(app_wr_en), .App_wr_addr(app_wr_addr),
    .App_wr_din(app_wr_din), .App_wr_dm(app_wr_dm),
    .write_clk(clk), .write_req(write_req), .write_req_ack(write_req_ack),
    .write_finish(write_finish), .write_fifo_full(write_fifo_full),
    .write_addr_0(21'd0), .write_addr_1(21'd0),
    .write_addr_2(21'd0), .write_addr_3(21'd0),
    .write_addr_index(2'd0), .write_len(WORDS),
    .write_en(write_en), .write_data(write_data)
);

always @(posedge clk) begin
    sdr_rd_en <= app_rd_en;
    if (app_rd_en) begin
        if (app_rd_addr >= WORDS) $fatal(1, "read addr %0d", app_rd_addr);
        sdr_rd_dout <= mem[app_rd_addr];
    end
    if (app_wr_en) begin
        if (app_wr_addr >= WORDS) $fatal(1, "write addr %0d", app_wr_addr);
        mem[app_wr_addr] <= app_wr_din;
    end
end

always @(posedge clk) begin
    if (rst) begin
        state <= 0;
        write_req <= 0;
        read_req <= 0;
        read_active <= 0;
        write_count <= 0;
        read_count <= 0;
        settle <= 0;
    end else case (state)
        0: begin write_req <= 1; state <= 1; end
        1: if (write_req_ack) begin write_req <= 0; state <= 2; end
        2: if (settle == 63) state <= 3;
           else settle <= settle + 1'b1;
        3: if (write_en) begin
            if (write_count == WORDS-1) state <= 4;
            else write_count <= write_count + 1'b1;
        end
        4: if (write_finish) begin read_req <= 1; state <= 5; end
        5: if (read_req_ack) begin
            read_req <= 0;
            read_active <= 1;
            state <= 6;
        end
        6: if (read_fifo_valid) begin
            if (read_data !== (32'hA5000000 + read_count))
                $fatal(1, "word %0d got %h expected %h", read_count,
                       read_data, 32'hA5000000 + read_count);
            if (read_count == WORDS-1) begin
                $display("PASS: %0d ordered words through write and read FIFOs", WORDS);
                $finish;
            end
            read_count <= read_count + 1'b1;
        end
    endcase
end

initial begin
    repeat (4) @(negedge clk);
    rst = 0;
    #2000000;
    $fatal(1, "timeout state=%0d write=%0d read=%0d", state, write_count, read_count);
end
endmodule

`default_nettype wire
