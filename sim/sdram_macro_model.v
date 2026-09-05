`timescale 1ns / 1ps
`default_nettype none

// Functional model for command-sequence regression only. It is not an
// electrical timing model and is never included in Tang Dynasty synthesis.
module EG_PHY_SDRAM_2M_32 (
    input  wire        clk,
    input  wire        ras_n,
    input  wire        cas_n,
    input  wire        we_n,
    input  wire [10:0] addr,
    input  wire [1:0]  ba,
    inout  wire [31:0] dq,
    input  wire        cs_n,
    input  wire        dm0,
    input  wire        dm1,
    input  wire        dm2,
    input  wire        dm3,
    input  wire        cke
);

reg [10:0] active_row [0:3];
reg [31:0] memory [0:65535];
reg [15:0] pending_read_addr;
reg [2:0] pending_read_delay;
reg        dq_drive;
reg [31:0] dq_out;
integer i;

function [15:0] memory_addr;
    input [1:0] bank;
    input [10:0] row;
    input [7:0] column;
    begin
        memory_addr = {row[5:0], bank, column};
    end
endfunction

assign dq = dq_drive ? dq_out : 32'hzzzz_zzzz;

initial begin
    for (i = 0; i < 65536; i = i + 1)
        memory[i] = 32'd0;
    pending_read_delay = 3'd0;
    pending_read_addr = 16'd0;
    dq_drive = 1'b0;
    dq_out = 32'd0;
end

always @(posedge clk) begin
    dq_drive <= 1'b0;

    if (pending_read_delay != 3'd0) begin
        if (pending_read_delay == 3'd1) begin
            dq_out <= memory[pending_read_addr];
            dq_drive <= 1'b1;
            pending_read_delay <= 3'd0;
        end else begin
            pending_read_delay <= pending_read_delay - 3'd1;
        end
    end

    if (cke && !cs_n) begin
        if (!ras_n && cas_n && we_n) begin
            active_row[ba] <= addr;
        end else if (ras_n && !cas_n && we_n) begin
            pending_read_addr <= memory_addr(ba, active_row[ba], addr[7:0]);
            pending_read_delay <= 3'd3;
        end else if (ras_n && !cas_n && !we_n) begin
            memory[memory_addr(ba, active_row[ba], addr[7:0])] <= dq;
        end
    end
end

endmodule

`default_nettype wire
