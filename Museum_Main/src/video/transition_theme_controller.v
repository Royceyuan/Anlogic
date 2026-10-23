`timescale 1ns / 1ps
`default_nettype none

module transition_theme_controller (
    input  wire [1:0] theme,
    input  wire [1:0] context,
    input  wire [1:0] demo_step,
    output reg  [2:0] primitive_mode
);

localparam [2:0] FADE = 3'd0, WIPE = 3'd1,
                 CURTAIN = 3'd2, ZOOM_REVEAL = 3'd3;
localparam [1:0] VIDEO_TO_DETAIL = 2'd0,
                 DETAIL_TO_DETAIL = 2'd1;

always @(*) begin
    case (theme)
        2'd0: primitive_mode = (context == 2'd2) ? CURTAIN : FADE;
        2'd1: primitive_mode = (context == 2'd2) ? ZOOM_REVEAL : WIPE;
        2'd2: begin
            if (context == VIDEO_TO_DETAIL)
                primitive_mode = ZOOM_REVEAL;
            else if (context == DETAIL_TO_DETAIL)
                primitive_mode = WIPE;
            else
                primitive_mode = CURTAIN;
        end
        default: begin
            if (context == VIDEO_TO_DETAIL)
                primitive_mode = FADE;
            else if (context == DETAIL_TO_DETAIL)
                primitive_mode = {1'b0, demo_step};
            else
                primitive_mode = ZOOM_REVEAL;
        end
    endcase
end

endmodule

`default_nettype wire
