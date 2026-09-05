`timescale 1ns / 1ps
`default_nettype none

// Conservative 50 MHz, single-word controller for the EG4 integrated SDRAM.
// This diagnostic controller intentionally uses auto-precharge transactions;
// burst scheduling is deferred until single-word hardware readback is proven.
module sdram_native_50m #(
    parameter integer USE_SEPARATE_SDRAM_CLK = 0
)(
    input  wire        clk,
    input  wire        sdram_clk,
    input  wire        rst_n,

    input  wire        app_wr_en,
    input  wire [20:0] app_wr_addr,
    input  wire [31:0] app_wr_data,
    input  wire        app_rd_en,
    input  wire [20:0] app_rd_addr,
    output wire        init_done,
    output wire        busy,
    output reg         read_valid,
    output reg  [31:0] read_data
);

localparam [4:0] ST_POWER_UP       = 5'd0;
localparam [4:0] ST_INIT_PRE       = 5'd1;
localparam [4:0] ST_INIT_PRE_WAIT  = 5'd2;
localparam [4:0] ST_INIT_REF1      = 5'd3;
localparam [4:0] ST_INIT_REF1_WAIT = 5'd4;
localparam [4:0] ST_INIT_REF2      = 5'd5;
localparam [4:0] ST_INIT_REF2_WAIT = 5'd6;
localparam [4:0] ST_INIT_MODE      = 5'd7;
localparam [4:0] ST_INIT_MODE_WAIT = 5'd8;
localparam [4:0] ST_IDLE           = 5'd9;
localparam [4:0] ST_ACT_WRITE      = 5'd10;
localparam [4:0] ST_WRITE_RCD_WAIT = 5'd11;
localparam [4:0] ST_WRITE          = 5'd12;
localparam [4:0] ST_WRITE_WAIT     = 5'd13;
localparam [4:0] ST_ACT_READ       = 5'd14;
localparam [4:0] ST_READ_RCD_WAIT  = 5'd15;
localparam [4:0] ST_READ           = 5'd16;
localparam [4:0] ST_READ_WAIT      = 5'd17;
localparam [4:0] ST_REFRESH        = 5'd18;
localparam [4:0] ST_REFRESH_WAIT   = 5'd19;

// 50 MHz timing: all wait values are intentionally more conservative than
// the integrated SDRAM's minimum requirements.
localparam [13:0] POWER_UP_CYCLES = 14'd9999; // 200 us at 50 MHz
localparam [3:0]  T_RP_CYCLES     = 4'd2;
localparam [3:0]  T_RFC_CYCLES    = 4'd4;
localparam [3:0]  T_MRD_CYCLES    = 4'd2;
localparam [3:0]  T_RCD_CYCLES    = 4'd2;
localparam [3:0]  T_WRITE_CYCLES  = 4'd4;
localparam [3:0]  T_READ_CYCLES   = 4'd4;
localparam [9:0]  REFRESH_CYCLES  = 10'd389; // about 7.8 us at 50 MHz

reg [4:0]  state;
reg [13:0] power_up_count;
reg [3:0]  wait_count;
reg [9:0]  refresh_count;
reg [3:0]  init_refresh_count;
reg        refresh_due;
reg        init_done_r;

reg [20:0] active_addr;
reg [31:0] active_wdata;

reg        sdram_cke;
reg        sdram_cs_n;
reg        sdram_ras_n;
reg        sdram_cas_n;
reg        sdram_we_n;
reg [10:0] sdram_addr;
reg [1:0]  sdram_ba;
reg [3:0]  sdram_dm;
reg        sdram_dq_oe;
reg [31:0] sdram_dq_out;
wire [31:0] sdram_dq;
wire        macro_clk;
reg  [31:0] sdram_dq_sampled;

generate
    if (USE_SEPARATE_SDRAM_CLK) begin : g_separate_sdram_clk
        assign macro_clk = sdram_clk;
    end else begin : g_shared_sdram_clk
        assign macro_clk = clk;
    end
endgenerate

assign init_done = init_done_r;
assign busy = !init_done_r || (state != ST_IDLE);
assign sdram_dq = sdram_dq_oe ? sdram_dq_out : 32'hzzzz_zzzz;

// Register the hard-IP read bus on the falling edge. The hard macro changes
// DQ after its active clock edge; sampling on the opposite edge gives the
// returned data setup/hold margin before the controller consumes it.
generate
    if (USE_SEPARATE_SDRAM_CLK) begin : g_sample_separate_sdram_clk
        always @(negedge sdram_clk or negedge rst_n) begin
            if (!rst_n)
                sdram_dq_sampled <= 32'd0;
            else
                sdram_dq_sampled <= sdram_dq;
        end
    end else begin : g_sample_shared_sdram_clk
        always @(negedge clk or negedge rst_n) begin
            if (!rst_n)
                sdram_dq_sampled <= 32'd0;
            else
                sdram_dq_sampled <= sdram_dq;
        end
    end
endgenerate

EG_PHY_SDRAM_2M_32 u_sdram_macro (
    .clk   (macro_clk),
    .ras_n (sdram_ras_n),
    .cas_n (sdram_cas_n),
    .we_n  (sdram_we_n),
    .addr  (sdram_addr),
    .ba    (sdram_ba),
    .dq    (sdram_dq),
    .cs_n  (sdram_cs_n),
    .dm0   (sdram_dm[0]),
    .dm1   (sdram_dm[1]),
    .dm2   (sdram_dm[2]),
    .dm3   (sdram_dm[3]),
    .cke   (sdram_cke)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state          <= ST_POWER_UP;
        power_up_count <= 14'd0;
        wait_count     <= 4'd0;
        refresh_count  <= 10'd0;
        init_refresh_count <= 4'd0;
        refresh_due    <= 1'b0;
        init_done_r    <= 1'b0;
        active_addr    <= 21'd0;
        active_wdata   <= 32'd0;
        read_valid     <= 1'b0;
        read_data      <= 32'd0;
        sdram_cke      <= 1'b0;
        sdram_cs_n     <= 1'b1;
        sdram_ras_n    <= 1'b1;
        sdram_cas_n    <= 1'b1;
        sdram_we_n     <= 1'b1;
        sdram_addr     <= 11'd0;
        sdram_ba       <= 2'd0;
        sdram_dm       <= 4'hf;
        sdram_dq_oe    <= 1'b0;
        sdram_dq_out   <= 32'd0;
    end else begin
        // Default command is NOP. Commands below remain asserted for a full
        // clock period and are sampled by the hard macro on the next edge.
        sdram_cke   <= 1'b1;
        sdram_cs_n  <= 1'b0;
        sdram_ras_n <= 1'b1;
        sdram_cas_n <= 1'b1;
        sdram_we_n  <= 1'b1;
        sdram_dm    <= 4'h0;
        sdram_dq_oe <= 1'b0;
        read_valid  <= 1'b0;

        if (init_done_r) begin
            if (refresh_count == REFRESH_CYCLES) begin
                refresh_count <= 10'd0;
                refresh_due   <= 1'b1;
            end else begin
                refresh_count <= refresh_count + 10'd1;
            end
        end

        case (state)
            ST_POWER_UP: begin
                if (power_up_count == POWER_UP_CYCLES) begin
                    state      <= ST_INIT_PRE;
                    wait_count <= 4'd0;
                end else begin
                    power_up_count <= power_up_count + 14'd1;
                end
            end

            ST_INIT_PRE: begin
                sdram_ras_n <= 1'b0;
                sdram_we_n  <= 1'b0;
                sdram_addr  <= 11'b100_0000_0000;
                init_refresh_count <= 4'd0;
                wait_count  <= T_RP_CYCLES;
                state       <= ST_INIT_PRE_WAIT;
            end

            ST_INIT_PRE_WAIT: begin
                if (wait_count == 4'd0)
                    state <= ST_INIT_REF1;
                else
                    wait_count <= wait_count - 4'd1;
            end

            ST_INIT_REF1: begin
                sdram_ras_n <= 1'b0;
                sdram_cas_n <= 1'b0;
                wait_count  <= T_RFC_CYCLES;
                state       <= ST_INIT_REF1_WAIT;
            end

            ST_INIT_REF1_WAIT: begin
                if (wait_count == 4'd0) begin
                    // JEDEC requires eight auto-refresh commands after the
                    // initial precharge before loading the mode register.
                    if (init_refresh_count == 4'd7) begin
                        state <= ST_INIT_MODE;
                    end else begin
                        init_refresh_count <= init_refresh_count + 4'd1;
                        state <= ST_INIT_REF1;
                    end
                end else begin
                    wait_count <= wait_count - 4'd1;
                end
            end

            ST_INIT_REF2: begin
                sdram_ras_n <= 1'b0;
                sdram_cas_n <= 1'b0;
                wait_count  <= T_RFC_CYCLES;
                state       <= ST_INIT_REF2_WAIT;
            end

            ST_INIT_REF2_WAIT: begin
                if (wait_count == 4'd0)
                    state <= ST_INIT_MODE;
                else
                    wait_count <= wait_count - 4'd1;
            end

            ST_INIT_MODE: begin
                // Single-word burst, sequential access, CAS latency 3,
                // single write bursts.
                sdram_ras_n <= 1'b0;
                sdram_cas_n <= 1'b0;
                sdram_we_n  <= 1'b0;
                sdram_addr  <= 11'b010_0011_0000;
                wait_count  <= T_MRD_CYCLES;
                state       <= ST_INIT_MODE_WAIT;
            end

            ST_INIT_MODE_WAIT: begin
                if (wait_count == 4'd0) begin
                    init_done_r <= 1'b1;
                    state       <= ST_IDLE;
                end else begin
                    wait_count <= wait_count - 4'd1;
                end
            end

            ST_IDLE: begin
                if (refresh_due) begin
                    state <= ST_REFRESH;
                end else if (app_wr_en) begin
                    active_addr  <= app_wr_addr;
                    active_wdata <= app_wr_data;
                    state        <= ST_ACT_WRITE;
                end else if (app_rd_en) begin
                    active_addr <= app_rd_addr;
                    state       <= ST_ACT_READ;
                end
            end

            ST_ACT_WRITE: begin
                sdram_ras_n <= 1'b0;
                sdram_ba    <= active_addr[9:8];
                sdram_addr  <= active_addr[20:10];
                wait_count  <= T_RCD_CYCLES;
                state       <= ST_WRITE_RCD_WAIT;
            end

            ST_WRITE_RCD_WAIT: begin
                if (wait_count == 4'd0)
                    state <= ST_WRITE;
                else
                    wait_count <= wait_count - 4'd1;
            end

            ST_WRITE: begin
                sdram_cas_n  <= 1'b0;
                sdram_we_n   <= 1'b0;
                sdram_ba     <= active_addr[9:8];
                sdram_addr   <= {1'b1, 2'b00, active_addr[7:0]};
                sdram_dq_oe  <= 1'b1;
                sdram_dq_out <= active_wdata;
                wait_count   <= T_WRITE_CYCLES;
                state        <= ST_WRITE_WAIT;
            end

            ST_WRITE_WAIT: begin
                if (wait_count == 4'd0)
                    state <= ST_IDLE;
                else
                    wait_count <= wait_count - 4'd1;
            end

            ST_ACT_READ: begin
                sdram_ras_n <= 1'b0;
                sdram_ba    <= active_addr[9:8];
                sdram_addr  <= active_addr[20:10];
                wait_count  <= T_RCD_CYCLES;
                state       <= ST_READ_RCD_WAIT;
            end

            ST_READ_RCD_WAIT: begin
                if (wait_count == 4'd0)
                    state <= ST_READ;
                else
                    wait_count <= wait_count - 4'd1;
            end

            ST_READ: begin
                sdram_cas_n <= 1'b0;
                sdram_ba    <= active_addr[9:8];
                sdram_addr  <= {1'b1, 2'b00, active_addr[7:0]};
                wait_count  <= T_READ_CYCLES;
                state       <= ST_READ_WAIT;
            end

            ST_READ_WAIT: begin
                if (wait_count == 4'd0) begin
                    read_data  <= sdram_dq_sampled;
                    read_valid <= 1'b1;
                    state      <= ST_IDLE;
                end else begin
                    wait_count <= wait_count - 4'd1;
                end
            end

            ST_REFRESH: begin
                sdram_ras_n <= 1'b0;
                sdram_cas_n <= 1'b0;
                wait_count  <= T_RFC_CYCLES;
                refresh_due <= 1'b0;
                state       <= ST_REFRESH_WAIT;
            end

            ST_REFRESH_WAIT: begin
                if (wait_count == 4'd0)
                    state <= ST_IDLE;
                else
                    wait_count <= wait_count - 4'd1;
            end

            default: state <= ST_POWER_UP;
        endcase
    end
end

endmodule

`default_nettype wire
