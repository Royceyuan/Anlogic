`timescale 1ns / 1ps
`default_nettype none

// Minimal SDRAM boundary diagnostic.  It bypasses TF/BMP, line buffers and
// asynchronous frame FIFOs, then writes and reads 1024 application words.
// Addresses 479/480/511/512 are therefore exercised directly.
module top_1280x720_sdram_boundary_diag (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

localparam integer TEST_WORDS = 1024;
localparam [2:0] S_WAIT_INIT = 3'd0;
localparam [2:0] S_WRITE = 3'd1;
localparam [2:0] S_WAIT_WRITE = 3'd2;
localparam [2:0] S_READ_CMD = 3'd3;
localparam [2:0] S_WAIT_READ = 3'd4;
localparam [2:0] S_PASS = 3'd5;
localparam [2:0] S_FAIL = 3'd6;

wire mem_clk, mem_clk_sft, mem_rst_n, init_done, init_ref_valid, mem_busy, read_valid;
wire app_wr_en, app_rd_en;
wire [20:0] app_wr_addr, app_rd_addr;
wire [31:0] app_wr_data, read_data;
wire [3:0] status;
reg [2:0] state;
reg [10:0] write_addr_r, read_addr_r;
reg [10:0] fail_addr_r;
reg [31:0] fail_data_r;
reg busy_seen;
reg [25:0] heartbeat_count;

assign app_wr_en = (state == S_WRITE) && init_done && !mem_busy;
assign app_wr_addr = {10'd0, write_addr_r};
assign app_wr_data = 32'hA5000000 + write_addr_r;
assign app_rd_en = (state == S_READ_CMD) && init_done && !mem_busy;
assign app_rd_addr = {10'd0, read_addr_r};
assign status = (state == S_PASS) ? 4'h4 :
               (state == S_FAIL) ? 4'hf : {1'b0, state};

reset_sync u_mem_reset_sync (.clk(mem_clk), .arst_n(key_n[0]), .srst_n(mem_rst_n));
sys_pll u_sys_pll (.refclk(clk_50m), .reset(1'b0), .clk0_out(),
                   .clk1_out(mem_clk), .clk2_out(mem_clk_sft));

sdram u_sdram (
    .Clk(mem_clk), .Clk_sft(mem_clk_sft), .Rst(~mem_rst_n),
    .Sdr_init_done(init_done), .Sdr_init_ref_vld(init_ref_valid),
    .Sdr_busy(mem_busy), .App_wr_en(app_wr_en), .App_wr_addr(app_wr_addr),
    .App_wr_dm(4'b0000), .App_wr_din(app_wr_data), .App_rd_en(app_rd_en),
    .App_rd_addr(app_rd_addr), .Sdr_rd_en(read_valid), .Sdr_rd_dout(read_data),
    .dbg_write_cmd(), .dbg_ba(), .dbg_addr(), .dbg_dm(), .dbg_dq(),
    .dbg_ras_n(), .dbg_cas_n(), .dbg_we_n(), .dbg_sdram_clk()
);

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        state       <= S_WAIT_INIT;
        write_addr_r<= 11'd0;
        read_addr_r <= 11'd0;
        fail_addr_r <= 11'd0;
        fail_data_r <= 32'd0;
        busy_seen   <= 1'b0;
    end else begin
        case (state)
            S_WAIT_INIT: if (init_done) state <= S_WRITE;
            S_WRITE: if (app_wr_en) begin
                if (write_addr_r == TEST_WORDS - 1) begin
                    write_addr_r <= 11'd0;
                    busy_seen <= 1'b0;
                    state <= S_WAIT_WRITE;
                end else write_addr_r <= write_addr_r + 1'b1;
            end
            S_WAIT_WRITE: begin
                if (mem_busy) busy_seen <= 1'b1;
                else if (busy_seen) begin
                    read_addr_r <= 11'd0;
                    state <= S_READ_CMD;
                end
            end
            S_READ_CMD: if (app_rd_en) state <= S_WAIT_READ;
            S_WAIT_READ: if (read_valid) begin
                if (read_data !== (32'hA5000000 + read_addr_r)) begin
                    fail_addr_r <= read_addr_r;
                    fail_data_r <= read_data;
                    state <= S_FAIL;
                end else if (read_addr_r == TEST_WORDS - 1) begin
                    state <= S_PASS;
                end else begin
                    read_addr_r <= read_addr_r + 1'b1;
                    state <= S_READ_CMD;
                end
            end
            default: state <= state;
        endcase
    end
end

always @(posedge mem_clk or negedge mem_rst_n)
    if (!mem_rst_n) heartbeat_count <= 26'd0;
    else heartbeat_count <= heartbeat_count + 1'b1;

assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = (state == S_PASS);
assign led[3] = (state == S_FAIL);

// 7-seg: status nibble followed by the first failing address low 12 bits.
seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n),
    .value({status, fail_addr_r}), .seg_data(seg_data), .seg_sel(seg_sel)
);

assign sd_clk = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;
assign vga_hs = 1'b1;
assign vga_vs = 1'b1;
assign vga_d = (state == S_PASS) ? 12'h0F0 :
              (state == S_FAIL) ? 12'hF00 : 12'h00F;
assign hdmi1_clk_p = 1'b0;
assign hdmi1_d2_p = 1'b0;
assign hdmi1_d1_p = 1'b0;
assign hdmi1_d0_p = 1'b0;

endmodule
`default_nettype wire
