`timescale 1ns / 1ps
`default_nettype none

module product_show_controller #(
    parameter integer VIDEO_HOLD_CYCLES = 150_000_000,
    parameter integer DETAIL_HOLD_CYCLES = 150_000_000,
    parameter integer TRANSITION_HOLD_CYCLES = 35_000_000,
    parameter integer PRODUCT_COUNT = 2
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       key_pause,
    input  wire       key_previous,
    input  wire       key_next,
    output reg  [3:0] image_index,
    output reg  [3:0] product_index,
    output reg  [2:0] state,
    output reg        pause_flag,
    output reg  [1:0] transition_context,
    output reg  [1:0] demo_step
);

localparam [2:0] PS_LOAD_PRODUCT      = 3'd0,
                 PS_VIDEO_PLAY        = 3'd1,
                 PS_VIDEO_TO_DETAIL   = 3'd2,
                 PS_DETAIL_HOLD       = 3'd3,
                 PS_DETAIL_TRANSITION = 3'd4,
                 PS_PRODUCT_END       = 3'd5,
                 PS_PRODUCT_TRANSITION= 3'd6,
                 PS_NEXT_PRODUCT      = 3'd7;
localparam [1:0] VIDEO_TO_DETAIL   = 2'd0,
                 DETAIL_TO_DETAIL = 2'd1,
                 PRODUCT_TO_PRODUCT = 2'd2;

reg [1:0] detail_index;
reg [28:0] hold_count;

function [3:0] next_product;
    input [3:0] current;
    begin
        next_product = (current == PRODUCT_COUNT - 1) ? 4'd0 : current + 1'b1;
    end
endfunction

function [3:0] previous_product;
    input [3:0] current;
    begin
        previous_product = (current == 0) ? PRODUCT_COUNT - 1 : current - 1'b1;
    end
endfunction

function [3:0] placeholder_image;
    input [3:0] product;
    begin
        placeholder_image = (product == 0) ? 4'd0 : 4'd4;
    end
endfunction

function [3:0] detail_image;
    input [3:0] product;
    input [1:0] detail;
    begin
        detail_image = (product == 0) ? detail + 1'b1 : 4'd3 - detail;
    end
endfunction

always @(*) begin
    transition_context = VIDEO_TO_DETAIL;
    case (state)
        PS_LOAD_PRODUCT,
        PS_VIDEO_PLAY: image_index = placeholder_image(product_index);
        PS_VIDEO_TO_DETAIL: image_index = detail_image(product_index, 2'd0);
        PS_DETAIL_HOLD,
        PS_DETAIL_TRANSITION,
        PS_PRODUCT_END: image_index = detail_image(product_index, detail_index);
        default: begin
            image_index = placeholder_image(product_index);
            transition_context = PRODUCT_TO_PRODUCT;
        end
    endcase
    if (state == PS_DETAIL_TRANSITION)
        transition_context = DETAIL_TO_DETAIL;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        product_index <= 4'd0;
        state <= PS_LOAD_PRODUCT;
        pause_flag <= 1'b0;
        demo_step <= 2'd0;
        detail_index <= 2'd0;
        hold_count <= 29'd0;
    end else if (!enable) begin
        product_index <= 4'd0;
        state <= PS_LOAD_PRODUCT;
        pause_flag <= 1'b0;
        demo_step <= 2'd0;
        detail_index <= 2'd0;
        hold_count <= 29'd0;
    end else if (key_previous) begin
        product_index <= previous_product(product_index);
        state <= PS_PRODUCT_TRANSITION;
        detail_index <= 2'd0;
        hold_count <= 29'd0;
    end else if (key_next) begin
        product_index <= next_product(product_index);
        state <= PS_PRODUCT_TRANSITION;
        detail_index <= 2'd0;
        hold_count <= 29'd0;
    end else if (key_pause) begin
        pause_flag <= ~pause_flag;
    end else begin
        case (state)
            PS_LOAD_PRODUCT: begin
                state <= PS_VIDEO_PLAY;
                hold_count <= 29'd0;
            end
            PS_VIDEO_PLAY: begin
                if (!pause_flag) begin
                    if (hold_count == VIDEO_HOLD_CYCLES - 1) begin
                        state <= PS_VIDEO_TO_DETAIL;
                        detail_index <= 2'd0;
                        hold_count <= 29'd0;
                    end else
                        hold_count <= hold_count + 1'b1;
                end
            end
            PS_VIDEO_TO_DETAIL: begin
                if (!pause_flag && hold_count == TRANSITION_HOLD_CYCLES - 1) begin
                    state <= PS_DETAIL_HOLD;
                    hold_count <= 29'd0;
                end else
                    hold_count <= hold_count + 1'b1;
            end
            PS_DETAIL_HOLD: begin
                if (!pause_flag) begin
                    if (hold_count == DETAIL_HOLD_CYCLES - 1) begin
                        hold_count <= 29'd0;
                        if (detail_index == 2'd2)
                            state <= PS_PRODUCT_END;
                        else begin
                            detail_index <= detail_index + 1'b1;
                            demo_step <= demo_step + 1'b1;
                            state <= PS_DETAIL_TRANSITION;
                        end
                    end else
                        hold_count <= hold_count + 1'b1;
                end
            end
            PS_DETAIL_TRANSITION: begin
                if (!pause_flag && hold_count == TRANSITION_HOLD_CYCLES - 1) begin
                    state <= PS_DETAIL_HOLD;
                    hold_count <= 29'd0;
                end else
                    hold_count <= hold_count + 1'b1;
            end
            PS_PRODUCT_END: begin
                if (!pause_flag) begin
                    product_index <= next_product(product_index);
                    state <= PS_PRODUCT_TRANSITION;
                    hold_count <= 29'd0;
                end
            end
            PS_PRODUCT_TRANSITION: begin
                if (!pause_flag && hold_count == TRANSITION_HOLD_CYCLES - 1) begin
                    state <= PS_NEXT_PRODUCT;
                    hold_count <= 29'd0;
                end else
                    hold_count <= hold_count + 1'b1;
            end
            default: begin
                if (!pause_flag) begin
                    state <= PS_LOAD_PRODUCT;
                    hold_count <= 29'd0;
                end
            end
        endcase
    end
end

endmodule

`default_nettype wire
