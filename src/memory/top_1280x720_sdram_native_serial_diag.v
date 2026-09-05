`timescale 1ns / 1ps
`default_nettype none

// Final bounded SDRAM experiment: use the transparent 50 MHz controller and
// its opposite-edge DQ sampler, while retaining the serialized probe FSM.
module top_1280x720_sdram_native_serial_diag (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

localparam [3:0] S_WAIT_INIT=4'd0, S_WRITE=4'd1, S_WAIT_WR=4'd2,
                 S_READ=4'd3, S_WAIT_RD=4'd4, S_PASS=4'd5, S_FAIL=4'd6;
localparam integer PROBE_COUNT=5;
wire clk_g, clk_sdram, rst_n, init_done, busy, read_valid;
wire app_wr_en, app_rd_en;
wire [20:0] app_wr_addr, app_rd_addr;
wire [31:0] app_wr_data, read_data;
reg [3:0] state;
reg [2:0] probe;
reg busy_seen;
reg [10:0] fail_addr;
reg [31:0] actual_data, expected_data;
reg [25:0] heartbeat;
wire [10:0] probe_addr = (probe==0) ? 11'd0 :
                         (probe==1) ? 11'd479 :
                         (probe==2) ? 11'd480 :
                         (probe==3) ? 11'd511 : 11'd512;
wire [31:0] probe_data = 32'h5A000000 + probe_addr;
wire video_clk, video_clk_5x, hs_i, vs_i, de_i;
wire [23:0] diag_rgb = (state==S_FAIL) ? 24'hFF0000 :
                        (state==S_PASS) ? 24'h00FF00 : 24'h0000FF;
reg [15:0] display_value;

// C0 is the controller clock; C1 is the 180-degree SDRAM clock.
sdram_pll_50m_phased u_mem_pll (.refclk(clk_50m), .reset(~key_n[0]),
    .clk0_out(clk_g), .clk1_out(clk_sdram), .clk2_out());
reset_sync u_reset_sync (.clk(clk_g), .arst_n(key_n[0]), .srst_n(rst_n));

sdram_native_50m #(.USE_SEPARATE_SDRAM_CLK(1)) u_native (
    .clk(clk_g), .sdram_clk(clk_sdram), .rst_n(rst_n),
    .app_wr_en(app_wr_en), .app_wr_addr(app_wr_addr), .app_wr_data(app_wr_data),
    .app_rd_en(app_rd_en), .app_rd_addr(app_rd_addr), .init_done(init_done),
    .busy(busy), .read_valid(read_valid), .read_data(read_data)
);

assign app_wr_en = (state==S_WRITE) && init_done && !busy;
assign app_wr_addr = {10'd0, probe_addr};
assign app_wr_data = probe_data;
assign app_rd_en = (state==S_READ) && init_done && !busy;
assign app_rd_addr = {10'd0, probe_addr};

always @(posedge clk_g or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_WAIT_INIT; probe <= 0; busy_seen <= 0;
        fail_addr <= 0; actual_data <= 0; expected_data <= 0;
    end else begin
        case (state)
            S_WAIT_INIT: if (init_done) state <= S_WRITE;
            S_WRITE: if (app_wr_en) begin busy_seen <= 0; state <= S_WAIT_WR; end
            S_WAIT_WR: begin
                if (busy) busy_seen <= 1;
                else if (busy_seen) begin busy_seen <= 0; state <= S_READ; end
            end
            S_READ: if (app_rd_en) state <= S_WAIT_RD;
            S_WAIT_RD: if (read_valid) begin
                actual_data <= read_data; expected_data <= probe_data;
                if (read_data !== probe_data) begin
                    fail_addr <= probe_addr; state <= S_FAIL;
                end else if (probe == PROBE_COUNT-1) state <= S_PASS;
                else begin probe <= probe + 1'b1; state <= S_WRITE; end
            end
            default: state <= state;
        endcase
    end
end

always @(posedge clk_g or negedge rst_n)
    if (!rst_n) heartbeat <= 0; else heartbeat <= heartbeat + 1'b1;

assign led[0] = heartbeat[25];
assign led[1] = init_done;
assign led[2] = (state==S_PASS);
assign led[3] = (state==S_FAIL);

always @(*) begin
    case (sw)
        4'b0000: display_value = (state==S_FAIL) ? 16'hDEAD :
                                  (state==S_PASS) ? 16'hD0A5 :
                                  !init_done ? 16'hD000 : 16'hD001;
        4'b0001: display_value = {5'd0, fail_addr};
        4'b0010: display_value = actual_data[15:0];
        4'b0011: display_value = expected_data[15:0];
        4'b0100: display_value = actual_data[31:16];
        4'b0101: display_value = expected_data[31:16];
        4'b0110: display_value = {5'd0, probe_addr};
        default: display_value = {13'd0, probe};
    endcase
end

seg_hex_display u_seg (.clk(clk_g), .rst_n(rst_n), .value(display_value),
                       .seg_data(seg_data), .seg_sel(seg_sel));
video_pll_75m u_video_pll (.refclk(clk_g), .reset(~key_n[0]),
                           .clk0_out(video_clk), .clk1_out(video_clk_5x));
video_timing_1280x720_pclk u_timing (.clk(video_clk), .rst_n(key_n[0]),
    .hs(hs_i), .vs(vs_i), .de(de_i), .x(), .y(), .frame_tick());
hdmi_tx u_hdmi (.PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(key_n[0]),
    .VGA_HS(hs_i), .VGA_VS(vs_i), .VGA_DE(de_i), .VGA_RGB(diag_rgb),
    .HDMI_CLK_P(hdmi1_clk_p), .HDMI_D2_P(hdmi1_d2_p),
    .HDMI_D1_P(hdmi1_d1_p), .HDMI_D0_P(hdmi1_d0_p));
assign vga_hs=hs_i; assign vga_vs=vs_i;
assign vga_d={diag_rgb[23:20],diag_rgb[15:12],diag_rgb[7:4]};
assign sd_clk=1'b0; assign sd_mosi=1'b0; assign sd_cs_n=1'b1;
endmodule
`default_nettype wire
