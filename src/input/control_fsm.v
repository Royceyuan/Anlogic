`timescale 1ns / 1ps
`default_nettype none

module control_fsm #(
    parameter integer AUTO_STEP_FRAMES = 60,
    parameter integer IMAGE_COUNT      = 2
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_tick,
    input  wire       media_ready,
    input  wire       error_in,
    input  wire       key_next_pulse,
    input  wire       key_prev_pulse,
    input  wire       key_overlay_pulse,
    input  wire       sw_auto,
    output reg  [3:0] status_code,
    output reg  [7:0] image_index,
    output reg        overlay_enable,
    output reg        auto_mode
);

reg [5:0] auto_frame_cnt;
localparam integer LAST_IMAGE_INDEX = IMAGE_COUNT - 1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status_code <= 4'd0;
        image_index <= 8'd0;
        overlay_enable <= 1'b1;
        auto_mode <= 1'b0;
        auto_frame_cnt <= 6'd0;
    end else begin
        auto_mode <= sw_auto;

        if (key_overlay_pulse) begin
            overlay_enable <= ~overlay_enable;
        end

        if (key_next_pulse && !sw_auto) begin
            if (image_index >= LAST_IMAGE_INDEX)
                image_index <= 8'd0;
            else
                image_index <= image_index + 8'd1;
        end else if (key_prev_pulse && !sw_auto) begin
            if (image_index == 8'd0)
                image_index <= LAST_IMAGE_INDEX;
            else
                image_index <= image_index - 8'd1;
        end else if (sw_auto && frame_tick) begin
            if (auto_frame_cnt == AUTO_STEP_FRAMES - 1) begin
                auto_frame_cnt <= 6'd0;
                if (image_index >= LAST_IMAGE_INDEX)
                    image_index <= 8'd0;
                else
                    image_index <= image_index + 8'd1;
            end else begin
                auto_frame_cnt <= auto_frame_cnt + 6'd1;
            end
        end else if (!sw_auto) begin
            auto_frame_cnt <= 6'd0;
        end

        if (error_in) begin
            status_code <= 4'hF;
        end else if (!media_ready) begin
            status_code <= 4'h1;
        end else if (sw_auto) begin
            status_code <= 4'h3;
        end else begin
            status_code <= 4'h2;
        end
    end
end

endmodule

`default_nettype wire
