`timescale 1ns/1ps
`default_nettype none

// Trial loading-side arithmetic: caller supplies clamped neighbours and Q0.8
// fractions. One multiplier is reused across RGB channels and both axes.
// ponytail: multi-cycle preload kernel, not a pixel-clock streaming scaler.
module rgb565_interpolate #(
`ifdef SCALE_HORIZONTAL
    parameter BILINEAR = 0,
`else
    parameter BILINEAR = 1,
`endif
    // Loader holds both samples until done; default still latches noisy inputs.
    parameter INPUTS_HELD_STABLE = 0
) (
    input wire clk, rst_n, start,
    input wire [15:0] p00, p01, p10, p11,
    input wire [7:0] fx, fy,
    output wire busy,
    output reg done,
    output reg [15:0] pixel
);
localparam IDLE=0, LOAD=1, MULTIPLY=2, ACCUMULATE=3;
reg [1:0] state, channel, axis;
reg [15:0] a, b, c, d;
reg [7:0] x, y;
reg signed [15:0] operand, h0, h1;
reg signed [8:0] weight;
reg signed [24:0] product, base;
wire signed [24:0] sum = base + product;
wire signed [24:0] rounded = sum + ((BILINEAR && axis==2) ? 25'sd32768 : 25'sd128);
reg signed [15:0] ca, cb, cc, cd;
wire [15:0] sample_a = INPUTS_HELD_STABLE ? p00 : a;
wire [15:0] sample_b = INPUTS_HELD_STABLE ? p01 : b;
wire [7:0] fraction_x = INPUTS_HELD_STABLE ? fx : x;
assign busy = state != IDLE;
always @(*) begin
    case (channel)
        0: begin ca={11'd0,sample_a[15:11]}; cb={11'd0,sample_b[15:11]}; cc={11'd0,c[15:11]}; cd={11'd0,d[15:11]}; end
        1: begin ca={10'd0,sample_a[10:5]}; cb={10'd0,sample_b[10:5]}; cc={10'd0,c[10:5]}; cd={10'd0,d[10:5]}; end
        default: begin ca={11'd0,sample_a[4:0]}; cb={11'd0,sample_b[4:0]}; cc={11'd0,c[4:0]}; cd={11'd0,d[4:0]}; end
    endcase
end
always @(posedge clk) begin
    // Product is only consumed after MULTIPLY. Datapath reset is unnecessary.
    if (state == MULTIPLY) product <= operand * weight;
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        pixel <= 0;
    end else begin
        done <= 0;
        case (state)
            IDLE: if (start) begin
                a<=p00; b<=p01; c<=p10; d<=p11; x<=fx; y<=fy;
                channel<=0; axis<=0; state<=LOAD;
            end
            LOAD: begin
                if (BILINEAR && axis==2) begin
                    operand<=h1-h0; weight<={1'b0,y};
                    base<=$signed(h0)*25'sd256;
                end else begin
                    operand <= (axis==0) ? cb-ca : cd-cc;
                    weight <= {1'b0,fraction_x};
                    base <= ((axis==0) ? ca : cc)*25'sd256;
                end
                state<=MULTIPLY;
            end
            MULTIPLY: state<=ACCUMULATE;
            ACCUMULATE: begin
                if (BILINEAR && axis!=2) begin
                    if (axis==0) h0<=sum[15:0]; else h1<=sum[15:0];
                    axis<=axis+1'b1; state<=LOAD;
                end else begin
                    case (channel)
                        0: pixel[15:11] <= (BILINEAR ? rounded[20:16] : rounded[12:8]);
                        1: pixel[10:5] <= (BILINEAR ? rounded[21:16] : rounded[13:8]);
                        2: pixel[4:0] <= (BILINEAR ? rounded[20:16] : rounded[12:8]);
                    endcase
                    if (channel==2) begin done<=1; state<=IDLE; end
                    else begin channel<=channel+1'b1; axis<=0; state<=LOAD; end
                end
            end
        endcase
    end
end
endmodule
`default_nettype wire
