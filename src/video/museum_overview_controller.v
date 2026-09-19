`timescale 1ns / 1ps
`default_nettype none

module museum_overview_controller #(
    parameter integer ITEM_COUNT = 5,
    parameter integer CONFIRM_FLASH_FRAMES = 8
) (
    input  wire       ctrl_clk,
    input  wire       ctrl_rst_n,
    input  wire       enable,
    input  wire       media_ready,
    input  wire       key_confirm,
    input  wire       key_previous,
    input  wire       key_next,
    output reg  [2:0] selected_index_ctrl,
    output reg        confirm_pulse,

    input  wire       video_clk,
    input  wire       video_rst_n,
    input  wire       video_frame_tick,
    output reg        enable_video,
    output reg  [2:0] selected_index_video,
    output wire       confirm_active_video
);

reg confirm_toggle_ctrl;
reg enable_ff1, enable_ff2;
reg [2:0] selected_ff1, selected_ff2;
reg confirm_toggle_ff1, confirm_toggle_ff2, confirm_toggle_seen;
reg [4:0] confirm_flash_count;

always @(posedge ctrl_clk or negedge ctrl_rst_n) begin
    if (!ctrl_rst_n) begin
        selected_index_ctrl <= 3'd0;
        confirm_pulse       <= 1'b0;
        confirm_toggle_ctrl <= 1'b0;
    end else begin
        confirm_pulse <= 1'b0;
        if (enable) begin
            if (key_previous) begin
                selected_index_ctrl <= (selected_index_ctrl == 0) ?
                                       ITEM_COUNT - 1 : selected_index_ctrl - 1'b1;
            end else if (key_next) begin
                selected_index_ctrl <= (selected_index_ctrl == ITEM_COUNT - 1) ?
                                       3'd0 : selected_index_ctrl + 1'b1;
            end else if (key_confirm && media_ready) begin
                confirm_pulse       <= 1'b1;
                confirm_toggle_ctrl <= ~confirm_toggle_ctrl;
            end
        end
    end
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        enable_ff1          <= 1'b0;
        enable_ff2          <= 1'b0;
        selected_ff1        <= 3'd0;
        selected_ff2        <= 3'd0;
        confirm_toggle_ff1  <= 1'b0;
        confirm_toggle_ff2  <= 1'b0;
        confirm_toggle_seen <= 1'b0;
        enable_video        <= 1'b0;
        selected_index_video <= 3'd0;
        confirm_flash_count <= 5'd0;
    end else begin
        enable_ff1         <= enable;
        enable_ff2         <= enable_ff1;
        selected_ff1       <= selected_index_ctrl;
        selected_ff2       <= selected_ff1;
        confirm_toggle_ff1 <= confirm_toggle_ctrl;
        confirm_toggle_ff2 <= confirm_toggle_ff1;

        if (video_frame_tick) begin
            enable_video         <= enable_ff2;
            selected_index_video <= selected_ff2;
            if (!enable_ff2) begin
                confirm_flash_count <= 5'd0;
                confirm_toggle_seen <= confirm_toggle_ff2;
            end else if (confirm_toggle_ff2 != confirm_toggle_seen) begin
                confirm_toggle_seen <= confirm_toggle_ff2;
                confirm_flash_count <= CONFIRM_FLASH_FRAMES;
            end else if (confirm_flash_count != 0) begin
                confirm_flash_count <= confirm_flash_count - 1'b1;
            end
        end
    end
end

assign confirm_active_video = (confirm_flash_count != 0);

endmodule

`default_nettype wire
