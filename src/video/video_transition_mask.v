`timescale 1ns / 1ps
`default_nettype none

// Single-frame transition effects.  The caller selects either the established
// fade path or the full-brightness path before this geometry-only mask.
module video_transition_mask #(
    parameter integer VIDEO_W = 800,
    parameter integer VIDEO_H = 600
) (
    input  wire [23:0] rgb_in,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire [2:0]  mode,
    input  wire [5:0]  progress,
    input  wire        enable,
    output reg  [23:0] rgb_out
);

reg [3:0] p;
reg reveal;
reg [10:0] h_limit;
reg [9:0] v_limit;
reg [10:0] diagonal_limit;
reg [9:0] center_half_w;
reg [8:0] center_half_h;
reg [10:0] dx;
reg [9:0] dy;
reg [5:0] block_sum;
reg [6:0] blind_dist;
reg [6:0] blind_half;

always @(*) begin
    // Geometry effects use thirteen steps.  The checkerboard gets a longer
    // 60-frame (~0.9 s) cadence so its block phases are visible.
    if (mode == 3'b100) begin
        case (progress)
            6'd0,  6'd1,  6'd2,  6'd3,  6'd4:  p = 4'd0;
            6'd5,  6'd6,  6'd7,  6'd8,  6'd9:  p = 4'd1;
            6'd10, 6'd11, 6'd12, 6'd13, 6'd14: p = 4'd2;
            6'd15, 6'd16, 6'd17, 6'd18, 6'd19: p = 4'd3;
            6'd20, 6'd21, 6'd22, 6'd23, 6'd24: p = 4'd4;
            6'd25, 6'd26, 6'd27, 6'd28, 6'd29: p = 4'd5;
            6'd30, 6'd31, 6'd32, 6'd33, 6'd34: p = 4'd6;
            6'd35, 6'd36, 6'd37, 6'd38, 6'd39: p = 4'd7;
            6'd40, 6'd41, 6'd42, 6'd43, 6'd44: p = 4'd8;
            6'd45, 6'd46, 6'd47, 6'd48, 6'd49: p = 4'd9;
            6'd50, 6'd51, 6'd52, 6'd53, 6'd54: p = 4'd10;
            6'd55, 6'd56, 6'd57, 6'd58, 6'd59: p = 4'd11;
            default: p = 4'd12;
        endcase
    end else begin
        case (progress)
            6'd0,  6'd1,  6'd2:  p = 4'd0;
            6'd3,  6'd4,  6'd5:  p = 4'd1;
            6'd6,  6'd7,  6'd8:  p = 4'd2;
            6'd9,  6'd10, 6'd11: p = 4'd3;
            6'd12, 6'd13, 6'd14: p = 4'd4;
            6'd15, 6'd16, 6'd17: p = 4'd5;
            6'd18, 6'd19, 6'd20: p = 4'd6;
            6'd21, 6'd22, 6'd23: p = 4'd7;
            6'd24, 6'd25, 6'd26: p = 4'd8;
            6'd27, 6'd28, 6'd29: p = 4'd9;
            6'd30, 6'd31, 6'd32: p = 4'd10;
            6'd33, 6'd34, 6'd35: p = 4'd11;
            default: p = 4'd12;
        endcase
    end

    case (p)
        4'd0: begin h_limit = 11'd64;  v_limit = 10'd48;  diagonal_limit = 11'd0;    end
        4'd1: begin h_limit = 11'd128; v_limit = 10'd96;  diagonal_limit = 11'd120;  end
        4'd2: begin h_limit = 11'd192; v_limit = 10'd144; diagonal_limit = 11'd240;  end
        4'd3: begin h_limit = 11'd256; v_limit = 10'd192; diagonal_limit = 11'd360;  end
        4'd4: begin h_limit = 11'd320; v_limit = 10'd240; diagonal_limit = 11'd480;  end
        4'd5: begin h_limit = 11'd384; v_limit = 10'd288; diagonal_limit = 11'd600;  end
        4'd6: begin h_limit = 11'd448; v_limit = 10'd336; diagonal_limit = 11'd720;  end
        4'd7: begin h_limit = 11'd512; v_limit = 10'd384; diagonal_limit = 11'd840;  end
        4'd8: begin h_limit = 11'd576; v_limit = 10'd432; diagonal_limit = 11'd960;  end
        4'd9: begin h_limit = 11'd640; v_limit = 10'd480; diagonal_limit = 11'd1080; end
        4'd10:begin h_limit = 11'd704; v_limit = 10'd528; diagonal_limit = 11'd1200; end
        4'd11:begin h_limit = 11'd768; v_limit = 10'd564; diagonal_limit = 11'd1320; end
        default: begin h_limit = VIDEO_W; v_limit = VIDEO_H; diagonal_limit = 11'd1400; end
    endcase

    case (p)
        4'd0: begin center_half_w = 10'd0;   center_half_h = 9'd0;   end
        4'd1: begin center_half_w = 10'd32;  center_half_h = 9'd24;  end
        4'd2: begin center_half_w = 10'd64;  center_half_h = 9'd48;  end
        4'd3: begin center_half_w = 10'd96;  center_half_h = 9'd72;  end
        4'd4: begin center_half_w = 10'd128; center_half_h = 9'd96;  end
        4'd5: begin center_half_w = 10'd160; center_half_h = 9'd120; end
        4'd6: begin center_half_w = 10'd192; center_half_h = 9'd144; end
        4'd7: begin center_half_w = 10'd224; center_half_h = 9'd168; end
        4'd8: begin center_half_w = 10'd256; center_half_h = 9'd192; end
        4'd9: begin center_half_w = 10'd288; center_half_h = 9'd216; end
        4'd10:begin center_half_w = 10'd320; center_half_h = 9'd240; end
        4'd11:begin center_half_w = 10'd352; center_half_h = 9'd264; end
        default: begin center_half_w = 10'd400; center_half_h = 9'd300; end
    endcase
    if (x >= (VIDEO_W / 2))
        dx = x - (VIDEO_W / 2);
    else
        dx = (VIDEO_W / 2) - x;
    if (y >= (VIDEO_H / 2))
        dy = y - (VIDEO_H / 2);
    else
        dy = (VIDEO_H / 2) - y;

    block_sum = x[7:5] + y[7:5];
    if (y < 10'd150) begin
        if (y <= 10'd75) blind_dist = 10'd75 - y;
        else blind_dist = y - 10'd75;
    end else if (y < 10'd300) begin
        if (y <= 10'd225) blind_dist = 10'd225 - y;
        else blind_dist = y - 10'd225;
    end else if (y < 10'd450) begin
        if (y <= 10'd375) blind_dist = 10'd375 - y;
        else blind_dist = y - 10'd375;
    end else begin
        if (y <= 10'd525) blind_dist = 10'd525 - y;
        else blind_dist = y - 10'd525;
    end
    case (p)
        4'd0: blind_half = 7'd0;
        4'd1: blind_half = 7'd6;
        4'd2: blind_half = 7'd12;
        4'd3: blind_half = 7'd18;
        4'd4: blind_half = 7'd24;
        4'd5: blind_half = 7'd30;
        4'd6: blind_half = 7'd36;
        4'd7: blind_half = 7'd42;
        4'd8: blind_half = 7'd48;
        4'd9: blind_half = 7'd54;
        4'd10: blind_half = 7'd60;
        4'd11: blind_half = 7'd66;
        default: blind_half = 7'd75;
    endcase
    reveal = 1'b1;
    case (mode)
        3'b001: reveal = (x < h_limit);                         // left wipe
        3'b010: reveal = (y < v_limit);                         // top wipe
        3'b011: reveal = (blind_dist <= blind_half);             // four horizontal blinds
        3'b100: begin                                            // checker blocks
            // Stagger the Manhattan wavefront by checker parity.  Adding the
            // parity bit makes neighboring 32x32 blocks open on alternating
            // geometry steps instead of collapsing into a plain wipe.
            reveal = ((block_sum + (x[5] ^ y[5])) <= {p, 1'b0});
        end
        3'b101: reveal = (dx <= center_half_w) && (dy <= center_half_h);
        3'b110: reveal = ((x + y) <= diagonal_limit);            // diagonal wipe
        default: reveal = 1'b1;                                  // fade fallback
    endcase

    if ((mode == 3'b000) || (mode == 3'b111))
        rgb_out = rgb_in;
    else if (!de)
        rgb_out = rgb_in;
    else if (!enable || reveal)
        rgb_out = rgb_in;
    else
        rgb_out = 24'h000000;
end

endmodule

`default_nettype wire
