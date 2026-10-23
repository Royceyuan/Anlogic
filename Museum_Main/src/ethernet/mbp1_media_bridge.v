`timescale 1ns/1ps
`default_nettype none

// Toggle handshakes keep each multi-bit command and status snapshot stable
// while it crosses the independent Ethernet and media clocks.
module mbp1_media_bridge #(
    parameter integer REFRESH_CYCLES = 6_250_000
) (
    input wire net_clk, input wire media_clk, input wire rst,
    input wire [7:0] media_mode,
    input wire [127:0] media_heartbeat,
    input wire [63:0] media_playback,
    input wire [95:0] media_display,
    input wire [127:0] media_diagnostic,
    output reg [7:0] net_mode,
    output reg [127:0] net_heartbeat,
    output reg [63:0] net_playback,
    output reg [95:0] net_display,
    output reg [127:0] net_diagnostic,
    input wire net_command_valid,
    input wire [7:0] net_command_type,
    input wire [63:0] net_command_payload,
    output reg net_command_done,
    output reg [7:0] net_command_result,
    output reg media_command_valid,
    output reg [7:0] media_command_type,
    output reg [63:0] media_command_payload,
    input wire media_command_done,
    input wire [7:0] media_command_result
);

reg [22:0] refresh_count;
reg status_request, status_request_ff1, status_request_ff2;
reg status_response, status_response_ff1, status_response_ff2, status_response_seen;
reg [423:0] status_hold;
reg command_request, command_request_ff1, command_request_ff2, command_request_seen;
reg command_response, command_response_ff1, command_response_ff2, command_response_seen;
reg [71:0] command_hold;
reg [7:0] result_hold;
reg command_busy, command_armed;

always @(posedge net_clk or posedge rst) begin
    if (rst) begin
        refresh_count <= 23'd0;
        status_request <= 1'b0;
        status_response_ff1 <= 1'b0;
        status_response_ff2 <= 1'b0;
        status_response_seen <= 1'b0;
        net_mode <= 8'd0;
        net_heartbeat <= 128'd0;
        net_playback <= 64'd0;
        net_display <= 96'd0;
        net_diagnostic <= 128'd0;
        command_request <= 1'b0;
        command_hold <= 72'd0;
        command_response_ff1 <= 1'b0;
        command_response_ff2 <= 1'b0;
        command_response_seen <= 1'b0;
        net_command_done <= 1'b0;
        net_command_result <= 8'd0;
        command_busy <= 1'b0;
        command_armed <= 1'b1;
    end else begin
        status_response_ff1 <= status_response;
        status_response_ff2 <= status_response_ff1;
        command_response_ff1 <= command_response;
        command_response_ff2 <= command_response_ff1;
        net_command_done <= 1'b0;
        if (refresh_count == REFRESH_CYCLES - 1) begin
            refresh_count <= 23'd0;
            status_request <= ~status_request;
        end else refresh_count <= refresh_count + 23'd1;
        if (status_response_ff2 != status_response_seen) begin
            status_response_seen <= status_response_ff2;
            {net_mode, net_heartbeat, net_playback, net_display,
             net_diagnostic} <= status_hold;
        end
        if (!net_command_valid) command_armed <= 1'b1;
        if (net_command_valid && command_armed && !command_busy) begin
            command_hold <= {net_command_type, net_command_payload};
            command_request <= ~command_request;
            command_busy <= 1'b1;
            command_armed <= 1'b0;
        end
        if (command_response_ff2 != command_response_seen) begin
            command_response_seen <= command_response_ff2;
            net_command_result <= result_hold;
            net_command_done <= 1'b1;
            command_busy <= 1'b0;
        end
    end
end

always @(posedge media_clk or posedge rst) begin
    if (rst) begin
        status_request_ff1 <= 1'b0;
        status_request_ff2 <= 1'b0;
        status_response <= 1'b0;
        status_hold <= 424'd0;
        command_request_ff1 <= 1'b0;
        command_request_ff2 <= 1'b0;
        command_request_seen <= 1'b0;
        command_response <= 1'b0;
        media_command_valid <= 1'b0;
        media_command_type <= 8'd0;
        media_command_payload <= 64'd0;
        result_hold <= 8'd0;
    end else begin
        status_request_ff1 <= status_request;
        status_request_ff2 <= status_request_ff1;
        command_request_ff1 <= command_request;
        command_request_ff2 <= command_request_ff1;
        media_command_valid <= 1'b0;
        if (status_request_ff2 != status_response) begin
            status_hold <= {media_mode, media_heartbeat, media_playback,
                            media_display, media_diagnostic};
            status_response <= status_request_ff2;
        end
        if (command_request_ff2 != command_request_seen) begin
            command_request_seen <= command_request_ff2;
            {media_command_type, media_command_payload} <= command_hold;
            media_command_valid <= 1'b1;
        end
        if (media_command_done) begin
            result_hold <= media_command_result;
            command_response <= ~command_response;
        end
    end
end
endmodule
`default_nettype wire
