`timescale 1ns / 1ps
`default_nettype none

// Buffers complete destination rows while the BMP byte stream is being
// parsed. The row index is carried with the output so a memory writer can
// place bottom-up BMP rows at their final SDRAM address.
module bmp_row_buffer #(
    parameter integer WIDTH  = 640,
    parameter integer HEIGHT = 480,
    parameter integer HIRES_WIDTH = WIDTH,
    parameter integer COL_BITS = (WIDTH <= 1) ? 1 : $clog2(WIDTH),
    parameter integer ROW_BITS = (HEIGHT <= 1) ? 1 : $clog2(HEIGHT)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  hires_frame,

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

reg [15:0] line_mem0 [0:HIRES_WIDTH-1];
reg [15:0] line_mem1 [0:HIRES_WIDTH-1];
wire [COL_BITS-1:0] active_width = hires_frame ? HIRES_WIDTH : WIDTH;

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

assign buf0_free = !ready0 && !(out_active && !out_buf);
assign buf1_free = !ready1 && !(out_active &&  out_buf);

assign out_valid    = out_active;
assign out_row      = out_buf ? row1 : row0;
assign out_pixel    = out_buf ? line_mem1[out_col] : line_mem0[out_col];
assign out_last     = out_active && (out_col == active_width - 1'b1);
assign out_row_done = out_valid && out_ready && out_last;
assign input_continue = !ready0 && !ready1 && !out_active;

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
            if (out_col == active_width - 1'b1) begin
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
                    line_mem0[in_col] <= in_pixel;
                    if (in_col == active_width - 1'b1) begin
                        ready0    <= 1'b1;
                        row0      <= in_row;
                        in_active <= 1'b0;
                    end
                end else if (buf1_free) begin
                    in_active     <= 1'b1;
                    in_buf        <= 1'b1;
                    in_row_active <= in_row;
                    in_col_last   <= in_col;
                    line_mem1[in_col] <= in_pixel;
                    if (in_col == active_width - 1'b1) begin
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
                if (!in_buf)
                    line_mem0[in_col] <= in_pixel;
                else
                    line_mem1[in_col] <= in_pixel;

                if (in_col == active_width - 1'b1) begin
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
                    line_mem1[in_col] <= in_pixel;
                    if (in_col == active_width - 1'b1) begin
                        ready1    <= 1'b1;
                        row1      <= in_row;
                        in_active <= 1'b0;
                    end
                end else if (in_buf && buf0_free) begin
                    in_buf        <= 1'b0;
                    in_row_active <= in_row;
                    in_col_last   <= in_col;
                    line_mem0[in_col] <= in_pixel;
                    if (in_col == active_width - 1'b1) begin
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

`default_nettype wire
