`default_nettype none

// Fixed 64-bar visualizer: playback PCM only, no feedback into audio.
module audio_visualizer_overlay #(
    parameter integer ENABLE_EMERGENCY = 0
) (
    input wire clk, input wire rst_n, input wire sample_valid,
    input wire signed [15:0] sample_left, input wire signed [15:0] sample_right,
    input wire pause, input wire emergency,
    input wire frame_tick, input wire hs_i, input wire vs_i, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    output wire hs_o, output wire vs_o, output wire de_o,
    output wire [10:0] x_o, output wire [9:0] y_o, output wire [23:0] rgb_o
);

localparam [10:0] BAR_X0 = 11'd128;
localparam [9:0] CENTER_Y = 10'd600;
localparam [7:0] MAX_HEIGHT = 8'd50;
reg [5:0] bar_index;
reg [3:0] samples_in_bar;
reg [7:0] peak_height;
reg display_bank, frame_pending, display_valid;
reg sample_valid_q;
reg [7:0] sample_height_q;

// Only abs(PCM)>>7 contributes to height. Preserve the carry from the discarded
// low bits, then clamp each channel before the much narrower stereo comparison.
wire [8:0] left_scaled = sample_left[15] ?
    (~sample_left[15:7] + (sample_left[6:0] == 0)) : sample_left[15:7];
wire [8:0] right_scaled = sample_right[15] ?
    (~sample_right[15:7] + (sample_right[6:0] == 0)) : sample_right[15:7];
wire [5:0] left_height = left_scaled > MAX_HEIGHT ? MAX_HEIGHT[5:0] : left_scaled[5:0];
wire [5:0] right_height = right_scaled > MAX_HEIGHT ? MAX_HEIGHT[5:0] : right_scaled[5:0];
wire [7:0] sample_height = {2'd0, left_height > right_height ? left_height : right_height};
wire [7:0] peak_next = (sample_height_q > peak_height) ? sample_height_q : peak_height;
// Alternating 12 and 13 samples makes 64 bars cover exactly 800 samples.
wire [3:0] final_sample_count = bar_index[0] ? 4'd12 : 4'd11;
wire bar_write_en = !pause && sample_valid_q && samples_in_bar == final_sample_count;
wire [7:0] bar_write_data = (peak_next < 8'd2) ? 8'd2 : peak_next;
wire [8:0] bar_write_addr = {2'b00, ~display_bank, bar_index};
wire [5:0] bar_read_index = (x_i >= BAR_X0 && x_i < BAR_X0 + 11'd1024) ?
                             ((x_i - BAR_X0) >> 4) : 6'd0;
wire [8:0] bar_read_addr = {2'b00, display_bank, bar_read_index};
wire [7:0] bar_read_data;

audio_bar_ram u_bar_ram (
    .wr_clk(clk), .wr_en(bar_write_en), .wr_addr(bar_write_addr), .wr_data(bar_write_data),
    .rd_clk(clk), .rd_addr(bar_read_addr), .rd_data(bar_read_data)
);

reg hs_s1, vs_s1, de_s1, hs_s2, vs_s2, de_s2;
reg [10:0] x_s1, x_s2;
reg [9:0] y_s1, y_s2;
reg [23:0] rgb_s1, rgb_s2;
reg [7:0] bar_height_s2;

function [23:0] bar_color;
    input [5:0] index;
    begin
        bar_color = index[0] ? 24'h5b7fff : 24'h4ec9e8;
    end
endfunction

wire in_bar_span = de_s2 && x_s2 >= BAR_X0 && x_s2 < BAR_X0 + 11'd1024 &&
                   y_s2 >= 10'd550 && y_s2 <= 10'd650;
wire [10:0] bar_offset = x_s2 - BAR_X0;
wire [5:0] bar_draw_index = bar_offset[9:4];
wire in_bar = in_bar_span && bar_offset[3:0] < 4'd6;
wire bar_hit = !pause && display_valid && in_bar &&
               y_s2 >= (CENTER_Y - bar_height_s2) &&
               y_s2 <= (CENTER_Y + bar_height_s2);

reg [23:0] rgb_visualizer;
always @(*) begin
    rgb_visualizer = rgb_s2;
    if (!de_s2)
        rgb_visualizer = 24'h000000;
    else if (bar_hit)
        rgb_visualizer = (ENABLE_EMERGENCY && emergency) ? 24'hff3030 :
                         bar_color(bar_draw_index);
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bar_index <= 0; samples_in_bar <= 0; peak_height <= 0;
        display_bank <= 0; frame_pending <= 0; display_valid <= 0;
        sample_valid_q <= 0; sample_height_q <= 0;
        hs_s1 <= 1; vs_s1 <= 1; de_s1 <= 0; hs_s2 <= 1; vs_s2 <= 1; de_s2 <= 0;
        x_s1 <= 0; y_s1 <= 0; rgb_s1 <= 0; x_s2 <= 0; y_s2 <= 0; rgb_s2 <= 0;
        bar_height_s2 <= 8'd2;
    end else begin
        sample_valid_q <= pause ? 1'b0 : sample_valid;
        if (!pause)
            sample_height_q <= sample_height;
        if (pause) begin
            bar_index <= 0; samples_in_bar <= 0; peak_height <= 0;
            frame_pending <= 0; display_valid <= 0;
        end else if (sample_valid_q) begin
            if (bar_write_en) begin
                samples_in_bar <= 0; peak_height <= 0;
                if (bar_index == 6'd63) begin
                    bar_index <= 0;
                    frame_pending <= 1;
                end else
                    bar_index <= bar_index + 1'b1;
            end else begin
                samples_in_bar <= samples_in_bar + 1'b1;
                peak_height <= peak_next;
            end
        end
        if (!pause && frame_tick && frame_pending) begin
            display_bank <= ~display_bank;
            frame_pending <= 0;
            display_valid <= 1;
        end
        hs_s1 <= hs_i; vs_s1 <= vs_i; de_s1 <= de_i;
        x_s1 <= x_i; y_s1 <= y_i; rgb_s1 <= rgb_i;
        hs_s2 <= hs_s1; vs_s2 <= vs_s1; de_s2 <= de_s1;
        x_s2 <= x_s1; y_s2 <= y_s1; rgb_s2 <= rgb_s1;
        bar_height_s2 <= bar_read_data;
    end
end

assign hs_o = hs_s2;
assign vs_o = vs_s2;
assign de_o = de_s2;
assign x_o = x_s2;
assign y_o = y_s2;
assign rgb_o = rgb_visualizer;
endmodule

module audio_bar_ram (
    input wire wr_clk, input wire wr_en, input wire [8:0] wr_addr, input wire [7:0] wr_data,
    input wire rd_clk, input wire [8:0] rd_addr, output wire [7:0] rd_data
);
`ifdef SIM
    reg [7:0] memory [0:511];
    reg [7:0] rd_q;
    always @(posedge wr_clk) if (wr_en) memory[wr_addr] <= wr_data;
    always @(posedge rd_clk) rd_q <= memory[rd_addr];
    assign rd_data = rd_q;
`else
    wire [7:0] unused_a;
    EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(8), .DATA_WIDTH_B(8), .ADDR_WIDTH_A(9), .ADDR_WIDTH_B(9),
        .DATA_DEPTH_A(512), .DATA_DEPTH_B(512), .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1),
        .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"), .RESETMODE("SYNC"),
        .DEBUGGABLE("NO"), .PACKABLE("NO"), .FORCE_KEEP("OFF"),
        .INIT_FILE("NONE"), .FILL_ALL("NONE"), .IMPLEMENT("9K")
    ) u_ram (
        .doa(unused_a), .dob(rd_data), .dia(wr_data), .dib(8'd0),
        .cea(wr_en), .ocea(1'b0), .clka(wr_clk), .wea(wr_en), .rsta(1'b0),
        .ceb(1'b1), .oceb(1'b1), .clkb(rd_clk), .web(1'b0), .rstb(1'b0),
        .bea(1'b1), .beb(1'b1), .addra(wr_addr), .addrb(rd_addr)
    );
`endif
endmodule

`default_nettype wire
