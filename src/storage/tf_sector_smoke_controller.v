`timescale 1ns / 1ps
`default_nettype none

// Requests exactly one 512-byte sector through the official SD SPI stack.
// This module deliberately knows nothing about FAT, BMP, SDRAM, or HDMI.
module tf_sector_smoke_controller #(
    parameter [31:0] SECTOR_ADDR = 32'd0,
    parameter integer READ_TIMEOUT_CYCLES = 25_000_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        read_start,

    input  wire        sd_init_done,
    output reg         sd_sec_read,
    output wire [31:0] sd_sec_read_addr,
    input  wire [7:0]  sd_sec_read_data,
    input  wire        sd_sec_read_data_valid,
    input  wire        sd_sec_read_end,

    output reg         init_seen,
    output reg         busy,
    output reg         read_done,
    output reg         read_error,
    output reg [9:0]   byte_count,
    output reg [31:0]  first_four_bytes
);

localparam [2:0] S_WAIT_INIT  = 3'd0;
localparam [2:0] S_WAIT_START = 3'd1;
localparam [2:0] S_READ       = 3'd2;
localparam [2:0] S_DONE       = 3'd3;
localparam [2:0] S_ERROR      = 3'd4;

reg [2:0] state;
reg [25:0] timeout_count;

assign sd_sec_read_addr = SECTOR_ADDR;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state            <= S_WAIT_INIT;
        timeout_count    <= 26'd0;
        sd_sec_read      <= 1'b0;
        init_seen        <= 1'b0;
        busy             <= 1'b0;
        read_done        <= 1'b0;
        read_error       <= 1'b0;
        byte_count       <= 10'd0;
        first_four_bytes <= 32'd0;
    end else begin
        case (state)
            S_WAIT_INIT: begin
                sd_sec_read <= 1'b0;
                if (sd_init_done) begin
                    init_seen <= 1'b1;
                    state <= S_WAIT_START;
                end
            end

            S_WAIT_START: begin
                if (read_start) begin
                    sd_sec_read      <= 1'b1;
                    busy             <= 1'b1;
                    byte_count       <= 10'd0;
                    first_four_bytes <= 32'd0;
                    timeout_count    <= 26'd0;
                    state            <= S_READ;
                end
            end

            S_READ: begin
                if (timeout_count >= READ_TIMEOUT_CYCLES - 1) begin
                    sd_sec_read <= 1'b0;
                    busy        <= 1'b0;
                    read_error  <= 1'b1;
                    state       <= S_ERROR;
                end else begin
                    timeout_count <= timeout_count + 26'd1;

                    if (sd_sec_read_end) begin
                        sd_sec_read <= 1'b0;
                        busy        <= 1'b0;
                        // Accept either an already-counted final byte or a
                        // final byte delivered together with the end pulse.
                        if (byte_count == 10'd512 ||
                            (sd_sec_read_data_valid && byte_count == 10'd511)) begin
                            if (sd_sec_read_data_valid)
                                byte_count <= 10'd512;
                            read_done <= 1'b1;
                            state     <= S_DONE;
                        end else begin
                            read_error <= 1'b1;
                            state      <= S_ERROR;
                        end
                    end else if (sd_sec_read_data_valid) begin
                        if (byte_count >= 10'd512) begin
                            sd_sec_read <= 1'b0;
                            busy        <= 1'b0;
                            read_error  <= 1'b1;
                            state       <= S_ERROR;
                        end else begin
                            case (byte_count)
                                10'd0: first_four_bytes[31:24] <= sd_sec_read_data;
                                10'd1: first_four_bytes[23:16] <= sd_sec_read_data;
                                10'd2: first_four_bytes[15:8]  <= sd_sec_read_data;
                                10'd3: first_four_bytes[7:0]   <= sd_sec_read_data;
                                default: begin end
                            endcase
                            byte_count <= byte_count + 10'd1;
                        end
                    end
                end
            end

            S_DONE, S_ERROR: begin
                sd_sec_read <= 1'b0;
            end

            default: begin
                state <= S_ERROR;
            end
        endcase
    end
end

endmodule

`default_nettype wire
