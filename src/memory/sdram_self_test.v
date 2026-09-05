`timescale 1ns / 1ps
`default_nettype none

// Minimal single-word SDRAM loopback. It avoids the frame FIFO scheduler so
// the memory primitive can be validated independently first.
module sdram_self_test #(
    parameter integer ADDR_BITS = 21,
    parameter [31:0] TEST_DATA  = 32'hA55A_3CC3,
    parameter integer TIMEOUT_BITS = 26
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     init_done,
    input  wire                     mem_busy,
    output reg                      app_wr_en,
    output reg  [ADDR_BITS-1:0]     app_wr_addr,
    output reg  [31:0]              app_wr_data,
    output reg                      app_rd_en,
    output reg  [ADDR_BITS-1:0]     app_rd_addr,
    input  wire                     read_valid,
    input  wire [31:0]              read_data,
    output reg  [3:0]               status,
    output reg  [31:0]              captured_data,
    output wire                     pass,
    output wire                     fail
);

localparam [2:0] ST_WAIT_INIT  = 3'd0;
localparam [2:0] ST_WRITE      = 3'd1;
localparam [2:0] ST_WAIT_WRITE = 3'd2;
localparam [2:0] ST_READ       = 3'd3;
localparam [2:0] ST_WAIT_READ  = 3'd4;
localparam [2:0] ST_PASS       = 3'd5;
localparam [2:0] ST_FAIL       = 3'd6;

reg [2:0] state;
reg       busy_seen;
reg [TIMEOUT_BITS-1:0] timeout_cnt;

assign pass = (state == ST_PASS);
assign fail = (state == ST_FAIL);

always @(*) begin
    app_wr_en   = 1'b0;
    app_wr_addr = {ADDR_BITS{1'b0}};
    app_wr_data = TEST_DATA;
    app_rd_en   = 1'b0;
    app_rd_addr = {ADDR_BITS{1'b0}};

    if (state == ST_WRITE && init_done && !mem_busy)
        app_wr_en = 1'b1;
    if (state == ST_READ && init_done && !mem_busy)
        app_rd_en = 1'b1;
end

always @(*) begin
    case (state)
        ST_WAIT_INIT:  status = 4'h0;
        ST_WRITE:      status = 4'h1;
        ST_WAIT_WRITE: status = 4'h2;
        ST_READ:       status = 4'h3;
        ST_WAIT_READ:  status = 4'h4;
        ST_PASS:       status = 4'h5;
        default:       status = 4'hF;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state         <= ST_WAIT_INIT;
        busy_seen     <= 1'b0;
        timeout_cnt   <= {TIMEOUT_BITS{1'b0}};
        captured_data <= 32'd0;
    end else begin
        if (state == ST_PASS || state == ST_FAIL) begin
            state <= state;
        end else if (state == ST_WAIT_INIT) begin
            timeout_cnt <= {TIMEOUT_BITS{1'b0}};
            busy_seen   <= 1'b0;
            if (init_done)
                state <= ST_WRITE;
        end else begin
            if (timeout_cnt == {TIMEOUT_BITS{1'b1}}) begin
                state <= ST_FAIL;
            end else begin
                timeout_cnt <= timeout_cnt + {{TIMEOUT_BITS-1{1'b0}}, 1'b1};

                if (mem_busy)
                    busy_seen <= 1'b1;

                case (state)
                    ST_WRITE: begin
                        if (!mem_busy) begin
                            state       <= ST_WAIT_WRITE;
                            timeout_cnt <= {TIMEOUT_BITS{1'b0}};
                            busy_seen   <= 1'b0;
                        end
                    end

                    ST_WAIT_WRITE: begin
                        if (busy_seen && !mem_busy) begin
                            state       <= ST_READ;
                            timeout_cnt <= {TIMEOUT_BITS{1'b0}};
                            busy_seen   <= 1'b0;
                        end
                    end

                    ST_READ: begin
                        if (!mem_busy) begin
                            state       <= ST_WAIT_READ;
                            timeout_cnt <= {TIMEOUT_BITS{1'b0}};
                            busy_seen   <= 1'b0;
                        end
                    end

                    ST_WAIT_READ: begin
                        if (read_valid) begin
                            captured_data <= read_data;
                            if (read_data == TEST_DATA)
                                state <= ST_PASS;
                            else
                                state <= ST_FAIL;
                        end
                    end

                    default: state <= ST_FAIL;
                endcase
            end
        end
    end
end

endmodule

`default_nettype wire
