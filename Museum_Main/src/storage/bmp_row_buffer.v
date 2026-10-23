`timescale 1ns / 1ps
`default_nettype none

// Buffers complete destination rows while the BMP byte stream is being
// parsed. The row index is carried with the output so a memory writer can
// place bottom-up BMP rows at their final SDRAM address.
module bmp_row_buffer #(
    parameter integer WIDTH  = 640,
    parameter integer HEIGHT = 480,
    parameter integer COL_BITS = (WIDTH <= 1) ? 1 : $clog2(WIDTH),
    parameter integer ROW_BITS = (HEIGHT <= 1) ? 1 : $clog2(HEIGHT)
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  in_valid,
    input  wire [ROW_BITS-1:0]   in_row,
    input  wire [COL_BITS-1:0]   in_col,
    input  wire [15:0]           in_pixel,
    output reg                   overflow,

    output wire                  out_valid,
    output wire [ROW_BITS-1:0]   out_row,
    output wire [15:0]           out_pixel,
    output wire                  out_last,
    input  wire                  out_ready,
    output wire                  out_row_done,
    // Safe boundary for requesting another 512-byte SD sector. An active
    // input row may remain; the other buffer is then free, and one sector
    // can produce at most 171 RGB pixels for the 640-pixel destination row.
    output wire                  input_continue
);

wire [15:0] line_mem0_rd;
wire [15:0] line_mem1_rd;

reg                  in_active;
reg                  in_buf;
reg [ROW_BITS-1:0]   in_row_active;
reg [COL_BITS-1:0]   in_col_last;

reg                  ready0;
reg                  ready1;
reg [ROW_BITS-1:0]   row0;
reg [ROW_BITS-1:0]   row1;

reg                  out_active;
reg                  out_buf;
reg [COL_BITS-1:0]   out_col;

wire buf0_free;
wire buf1_free;
wire write_buf0;
wire write_buf1;
wire read_buf0;
wire read_buf1;
wire [COL_BITS-1:0] read_col;

assign buf0_free = !ready0 && !(out_active && !out_buf);
assign buf1_free = !ready1 && !(out_active &&  out_buf);

assign write_buf0 = in_valid &&
                    ((!in_active && buf0_free) ||
                     (in_active && (in_row == in_row_active) && !in_buf) ||
                     (in_active && (in_row != in_row_active) && in_buf && buf0_free));
assign write_buf1 = in_valid &&
                    ((!in_active && !buf0_free && buf1_free) ||
                     (in_active && (in_row == in_row_active) && in_buf) ||
                     (in_active && (in_row != in_row_active) && !in_buf && buf1_free));
assign read_buf0 = (!out_active && ready0) ||
                   (out_active && !out_buf && out_ready && !out_last);
assign read_buf1 = (!out_active && !ready0 && ready1) ||
                   (out_active && out_buf && out_ready && !out_last);
assign read_col = out_active ? (out_col + 1'b1) : {COL_BITS{1'b0}};

assign out_valid    = out_active;
assign out_row      = out_buf ? row1 : row0;
assign out_pixel    = out_buf ? line_mem1_rd : line_mem0_rd;
assign out_last     = out_active && (out_col == WIDTH - 1);
assign out_row_done = out_valid && out_ready && out_last;
assign input_continue = !ready0 && !ready1 && !out_active;

bmp_row_bank_ram #(
    .ADDR_WIDTH(COL_BITS),
    .DATA_DEPTH(WIDTH)
) u_line_mem0 (
    .clk    (clk),
    .wr_en  (write_buf0),
    .wr_addr(in_col),
    .wr_data(in_pixel),
    .rd_en  (read_buf0),
    .rd_addr(read_col),
    .rd_data(line_mem0_rd)
);

bmp_row_bank_ram #(
    .ADDR_WIDTH(COL_BITS),
    .DATA_DEPTH(WIDTH)
) u_line_mem1 (
    .clk    (clk),
    .wr_en  (write_buf1),
    .wr_addr(in_col),
    .wr_data(in_pixel),
    .rd_en  (read_buf1),
    .rd_addr(read_col),
    .rd_data(line_mem1_rd)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_active    <= 1'b0;
        in_buf       <= 1'b0;
        in_row_active<= {ROW_BITS{1'b0}};
        in_col_last  <= {COL_BITS{1'b0}};
        ready0       <= 1'b0;
        ready1       <= 1'b0;
        row0         <= {ROW_BITS{1'b0}};
        row1         <= {ROW_BITS{1'b0}};
        out_active   <= 1'b0;
        out_buf      <= 1'b0;
        out_col      <= {COL_BITS{1'b0}};
        overflow     <= 1'b0;
    end else begin
        // Drain one completed row. The row stays stable while stalled.
        if (out_active && out_ready) begin
            if (out_col == WIDTH - 1) begin
                out_active <= 1'b0;
                out_col    <= {COL_BITS{1'b0}};
            end else begin
                out_col <= out_col + 1'b1;
            end
        end else if (!out_active) begin
            // A completed row is selected only after its final input write.
            if (ready0) begin
                out_active <= 1'b1;
                out_buf    <= 1'b0;
                out_col    <= {COL_BITS{1'b0}};
                ready0     <= 1'b0;
            end else if (ready1) begin
                out_active <= 1'b1;
                out_buf    <= 1'b1;
                out_col    <= {COL_BITS{1'b0}};
                ready1     <= 1'b0;
            end
        end

        if (in_valid) begin
            if (!in_active) begin
                // Start the first row, or the row after a completed buffer.
                if (buf0_free) begin
                    in_active     <= 1'b1;
                    in_buf        <= 1'b0;
                    in_row_active <= in_row;
                    in_col_last   <= in_col;
                    if (in_col == WIDTH - 1) begin
                        ready0    <= 1'b1;
                        row0      <= in_row;
                        in_active <= 1'b0;
                    end
                end else if (buf1_free) begin
                    in_active     <= 1'b1;
                    in_buf        <= 1'b1;
                    in_row_active <= in_row;
                    in_col_last   <= in_col;
                    if (in_col == WIDTH - 1) begin
                        ready1    <= 1'b1;
                        row1      <= in_row;
                        in_active <= 1'b0;
                    end
                end else begin
                    overflow <= 1'b1;
                end
            end else if (in_row == in_row_active) begin
                // Pixels within one row arrive in increasing destination X.
                in_col_last <= in_col;
                if (in_col == WIDTH - 1) begin
                    in_active <= 1'b0;
                    if (!in_buf) begin
                        ready0 <= 1'b1;
                        row0   <= in_row;
                    end else begin
                        ready1 <= 1'b1;
                        row1   <= in_row;
                    end
                end
            end else begin
                // A new row is legal only after the old row was complete.
                // The other line must be free because the input has no
                // back-pressure port; overflow is therefore sticky.
                if (!in_buf && buf1_free) begin
                    in_buf        <= 1'b1;
                    in_row_active <= in_row;
                    in_col_last   <= in_col;
                    if (in_col == WIDTH - 1) begin
                        ready1    <= 1'b1;
                        row1      <= in_row;
                        in_active <= 1'b0;
                    end
                end else if (in_buf && buf0_free) begin
                    in_buf        <= 1'b0;
                    in_row_active <= in_row;
                    in_col_last   <= in_col;
                    if (in_col == WIDTH - 1) begin
                        ready0    <= 1'b1;
                        row0      <= in_row;
                        in_active <= 1'b0;
                    end
                end else begin
                    overflow <= 1'b1;
                end
            end
        end
    end
end

endmodule

// EG_LOGIC_BRAM's NOREG output still has one synchronous array-read cycle.
// The read enable holds the current output pixel while the consumer stalls.
module bmp_row_bank_ram #(
    parameter integer ADDR_WIDTH = 10,
    parameter integer DATA_DEPTH = 960
)(
    input  wire                  clk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [15:0]           wr_data,
    input  wire                  rd_en,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [15:0]           rd_data
);

`ifdef SIM
reg [15:0] memory [0:DATA_DEPTH-1];
reg [15:0] rd_data_q;

always @(posedge clk) begin
    if (wr_en)
        memory[wr_addr] <= wr_data;
    if (rd_en)
        rd_data_q <= memory[rd_addr];
end

assign rd_data = rd_data_q;
`else
wire [15:0] unused_a;

EG_LOGIC_BRAM #(
    .DATA_WIDTH_A(16), .DATA_WIDTH_B(16),
    .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
    .DATA_DEPTH_A(1 << ADDR_WIDTH), .DATA_DEPTH_B(1 << ADDR_WIDTH),
    .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
    .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
    .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
    .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
    .IMPLEMENT("9K")
) u_ram (
    .doa(unused_a), .dob(rd_data), .dia(wr_data), .dib(16'd0),
    .cea(wr_en), .ocea(1'b0), .clka(clk), .wea(wr_en), .rsta(1'b0),
    .ceb(rd_en), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
    .bea(1'b1), .beb(1'b1), .addra(wr_addr), .addrb(rd_addr)
);
`endif

endmodule

`default_nettype wire
