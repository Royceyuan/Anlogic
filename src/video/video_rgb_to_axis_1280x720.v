`default_nettype none

// The HDMI 1.4b core accepts complete, uninterrupted active-video lines.
// Its generated timing is configured to the same 1280x720 raster as v73.
module video_rgb_to_axis_1280x720 (
    input  wire        clk,
    input  wire        rst,
    input  wire        vs_i,
    input  wire        de_i,
    input  wire [23:0] rgb_i,
    output reg         axis_user,
    output reg         axis_valid,
    output reg         axis_last,
    output reg [23:0]  axis_data
);

reg vs_d;
reg de_d;
reg frame_arm;
reg [10:0] x_count;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        vs_d       <= 1'b0;
        de_d       <= 1'b0;
        frame_arm  <= 1'b1;
        x_count    <= 11'd0;
        axis_user  <= 1'b0;
        axis_valid <= 1'b0;
        axis_last  <= 1'b0;
        axis_data  <= 24'd0;
    end else begin
        vs_d       <= vs_i;
        de_d       <= de_i;
        axis_user  <= 1'b0;
        axis_valid <= de_i;
        axis_last  <= 1'b0;
        axis_data  <= rgb_i;
        if (vs_d != vs_i)
            frame_arm <= 1'b1;
        if (de_i) begin
            if (!de_d) begin
                x_count <= 11'd0;
                if (frame_arm) begin
                    axis_user <= 1'b1;
                    frame_arm <= 1'b0;
                end
            end else begin
                x_count <= x_count + 1'b1;
            end
            // x_count is zero on the first active pixel, then advances on
            // following pixels.  Therefore the 1280th pixel sees 1278 here.
            if (de_d && x_count == 11'd1278)
                axis_last <= 1'b1;
        end else begin
            x_count <= 11'd0;
        end
    end
end

endmodule

`default_nettype wire
