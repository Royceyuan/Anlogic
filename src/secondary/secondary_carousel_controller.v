`timescale 1ns / 1ps
`default_nettype none

// Decoded MBP1 commands enter here in the 50 MHz domain. The future UDP
// receiver owns CRC, boot_id, seq/deduplication and ACK transmission.
module secondary_carousel_controller #(
    parameter integer PAGE_CYCLES = 250_000_000,
    parameter integer LINK_TIMEOUT_CYCLES = 100_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  frame_valid,
    input  wire        local_emergency,
    input  wire        cmd_valid,
    input  wire [7:0]  cmd_type,
    input  wire [7:0]  cmd_artifact_id,
    input  wire        cmd_confirmed,
    input  wire [7:0]  cmd_mode,
    input  wire [7:0]  cmd_lecture_phase,
    input  wire [7:0]  cmd_lecture_reason,
    input  wire [15:0] cmd_emergency_id,
    input  wire [7:0]  cmd_route_id,
    input  wire        cmd_emergency_active,
    output reg  [2:0]  page_index,
    output wire        emergency_active,
    output reg  [1:0]  link_state,
    output reg  [2:0]  master_artifact,
    output reg         info_active,
    output reg  [2:0]  info_artifact,
    output reg  [7:0]  active_route_id,
    output reg  [2:0]  cmd_result
);

localparam [1:0] LINK_WAIT = 2'd0, LINK_OK = 2'd1, LINK_LOST = 2'd2;
localparam [7:0] HELLO = 8'h01, HEARTBEAT = 8'h02, STATUS_QUERY = 8'h03;
localparam [7:0] ARTIFACT_SELECT = 8'h10, LECTURE_STATE = 8'h11;
localparam [7:0] PLAYBACK_STATE = 8'h12, EMERGENCY_SET = 8'h20;
localparam [7:0] EMERGENCY_CLEAR = 8'h21;
localparam [2:0] OK = 3'd0, UNSUPPORTED = 3'd3, INVALID_STATE = 3'd5;

reg [27:0] page_cycles;
reg [26:0] link_cycles;
reg remote_emergency;
reg [15:0] active_emergency_id;
reg local_ff1, local_ff2;
wire all_ready = &frame_valid;
assign emergency_active = remote_emergency | local_ff2;

always @(*) begin
    cmd_result = OK;
    if (cmd_valid) begin
        case (cmd_type)
            HELLO, HEARTBEAT, STATUS_QUERY: cmd_result = OK;
            ARTIFACT_SELECT, LECTURE_STATE, PLAYBACK_STATE:
                if ((cmd_artifact_id > 8'd4 && cmd_artifact_id != 8'hff) ||
                    (cmd_type == ARTIFACT_SELECT && cmd_confirmed &&
                     cmd_artifact_id == 8'hff))
                    cmd_result = INVALID_STATE;
            EMERGENCY_SET: cmd_result = OK;
            EMERGENCY_CLEAR:
                if (!remote_emergency || cmd_emergency_id != active_emergency_id)
                    cmd_result = INVALID_STATE;
            default: cmd_result = UNSUPPORTED;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        page_index <= 3'd0;
        page_cycles <= 28'd0;
        link_cycles <= 27'd0;
        link_state <= LINK_WAIT;
        master_artifact <= 3'd7;
        info_active <= 1'b0;
        info_artifact <= 3'd0;
        remote_emergency <= 1'b0;
        active_emergency_id <= 16'd0;
        active_route_id <= 8'd0;
        local_ff1 <= 1'b0;
        local_ff2 <= 1'b0;
    end else begin
        local_ff1 <= local_emergency;
        local_ff2 <= local_ff1;

        if (!all_ready || emergency_active) begin
            page_index <= 3'd0;
            page_cycles <= 28'd0;
        end else if (info_active) begin
            page_index <= info_artifact;
            page_cycles <= 28'd0;
        end else if (page_cycles == PAGE_CYCLES - 1) begin
            page_cycles <= 28'd0;
            page_index <= (page_index == 3'd4) ? 3'd0 : page_index + 1'b1;
        end else begin
            page_cycles <= page_cycles + 1'b1;
        end

        if (link_cycles == LINK_TIMEOUT_CYCLES - 1) begin
            link_cycles <= link_cycles;
            link_state <= LINK_LOST;
        end else link_cycles <= link_cycles + 1'b1;

        if (cmd_valid && cmd_result == OK) begin
            case (cmd_type)
                HELLO: begin
                    link_state <= LINK_WAIT;
                    link_cycles <= 27'd0;
                end
                HEARTBEAT: begin
                    link_state <= LINK_OK;
                    link_cycles <= 27'd0;
                    master_artifact <= (cmd_artifact_id <= 8'd4) ? cmd_artifact_id[2:0] : 3'd7;
                    if (cmd_mode == 8'd1) begin
                        info_active <= 1'b0;
                        page_index <= 3'd0;
                        page_cycles <= 28'd0;
                    end else if (cmd_mode == 8'd2 && cmd_artifact_id <= 8'd4) begin
                        info_active <= 1'b1;
                        info_artifact <= cmd_artifact_id[2:0];
                        page_index <= cmd_artifact_id[2:0];
                        page_cycles <= 28'd0;
                    end
                    if (cmd_emergency_active) begin
                        remote_emergency <= 1'b1;
                        active_emergency_id <= cmd_emergency_id;
                        active_route_id <= cmd_route_id;
                    end else if (remote_emergency && cmd_emergency_id == active_emergency_id)
                        remote_emergency <= 1'b0;
                end
                ARTIFACT_SELECT, LECTURE_STATE, PLAYBACK_STATE: begin
                    master_artifact <= (cmd_artifact_id <= 8'd4) ? cmd_artifact_id[2:0] : 3'd7;
                    if (cmd_type == ARTIFACT_SELECT && cmd_confirmed &&
                        cmd_artifact_id <= 8'd4) begin
                        info_active <= 1'b1;
                        info_artifact <= cmd_artifact_id[2:0];
                        page_index <= cmd_artifact_id[2:0];
                        page_cycles <= 28'd0;
                    end else if (cmd_type == LECTURE_STATE) begin
                        if (cmd_lecture_phase == 8'hff || cmd_lecture_reason == 8'd1) begin
                            info_active <= 1'b0;
                            page_index <= 3'd0;
                            page_cycles <= 28'd0;
                        end
                    end
                end
                EMERGENCY_SET: begin
                    remote_emergency <= 1'b1;
                    active_emergency_id <= cmd_emergency_id;
                    active_route_id <= cmd_route_id;
                end
                EMERGENCY_CLEAR: remote_emergency <= 1'b0;
                default: begin end
            endcase
        end
        if (emergency_active)
            info_active <= 1'b0;
    end
end

endmodule

`default_nettype wire
