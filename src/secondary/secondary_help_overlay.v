`timescale 1ns/1ps
`default_nettype none

// Local-only guide: one 160x90 RGB565 cache, fixed glyph ROM and frame-latched
// controls. Neither the media display selection nor MBP1 is changed by SW4.
module secondary_help_overlay (
    input wire clk, rst_n, de,
    input wire [10:0] x, pre_x,
    input wire [9:0] y, pre_y,
    input wire [23:0] base_rgb,
    input wire [3:0] switches_50m,
    input wire manual_50m, overview_50m, paused_50m,
    input wire [1:0] link_50m,
    input wire emergency_50m, emergency_bitmap_video, background_ready_50m,
    input wire write_clk, write_en,
    input wire [10:0] write_row, write_col,
    input wire [15:0] write_pixel,
    output reg [23:0] rgb
);
`include "src/secondary/secondary_help_font.vh"
reg [10:0] controls_ff1, controls_ff2, controls_frame;
wire [10:0] controls = {switches_50m, manual_50m, overview_50m,
                        paused_50m, link_50m, emergency_50m, background_ready_50m};
wire help_frame = controls_frame[10] && !controls_frame[1] && !emergency_bitmap_video;
wire [1:0] main_context = controls_frame[5] ? 2'd0 :
                         controls_frame[6] ? 2'd2 : 2'd1;
reg glyph_valid_q, heading_q;
reg [3:0] glyph_col_q;
reg font_bank_q;
wire [10:0] dx = pre_x - 11'd64;
wire [9:0] dy = pre_y - 10'd48;
wire [4:0] line = dy[9:5];
wire [255:0] line_codes = help_line(line, controls_frame[8:7], main_context,
                                   controls_frame[4], controls_frame[3:2]);
wire [7:0] glyph_code = line_codes >> {dx[9:5],3'b000};
wire [15:0] glyph_bits;
wire [15:0] background_pixel;
wire [13:0] write_address = ({7'd0,write_row[9:3]} << 7) +
                            ({7'd0,write_row[9:3]} << 5) + {6'd0,write_col[10:3]};
wire [13:0] read_address = ({7'd0,pre_y[9:3]} << 7) +
                           ({7'd0,pre_y[9:3]} << 5) + {6'd0,pre_x[10:3]};
wire cache_write = write_en && write_row < 720 && write_col < 1280 &&
                   write_row[2:0] == 0 && write_col[2:0] == 0;
// ponytail: the deliberately soft backdrop is sampled 8x; text is native 720p.
`ifdef SIM
reg [15:0] backdrop [0:16383];
reg [15:0] backdrop_q, glyph_q;
always @(posedge write_clk) if (cache_write) backdrop[write_address] <= write_pixel;
always @(posedge clk) begin
    backdrop_q <= backdrop[read_address];
    glyph_q <= help_font_init(glyph_code) >> {dy[4:1],4'b0000};
end
assign background_pixel = backdrop_q;
assign glyph_bits = glyph_q;
`else
wire [15:0] unused_a;
EG_LOGIC_BRAM #(
    .DATA_WIDTH_A(16), .DATA_WIDTH_B(16),
    .ADDR_WIDTH_A(14), .ADDR_WIDTH_B(14),
    .DATA_DEPTH_A(16384), .DATA_DEPTH_B(16384),
    .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
    .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
    .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
    .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
    .IMPLEMENT("32K")
) u_backdrop (
    .doa(unused_a), .dob(background_pixel), .dia(write_pixel), .dib(16'd0),
    .cea(cache_write), .ocea(1'b0), .clka(write_clk), .wea(cache_write), .rsta(1'b0),
    .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
    .bea(1'b1), .beb(1'b1), .addra(write_address), .addrb(read_address)
);
wire [15:0] font_data [0:1];
genvar bank;
generate for (bank=0;bank<2;bank=bank+1) begin : g_font
    EG_PHY_BRAM32K #(
        .MODE("DP16K"), .DATA_WIDTH_A("16"), .DATA_WIDTH_B("16"),
        .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
                .INIT_00(help_font_init(bank*128+0)),
                .INIT_01(help_font_init(bank*128+1)),
                .INIT_02(help_font_init(bank*128+2)),
                .INIT_03(help_font_init(bank*128+3)),
                .INIT_04(help_font_init(bank*128+4)),
                .INIT_05(help_font_init(bank*128+5)),
                .INIT_06(help_font_init(bank*128+6)),
                .INIT_07(help_font_init(bank*128+7)),
                .INIT_08(help_font_init(bank*128+8)),
                .INIT_09(help_font_init(bank*128+9)),
                .INIT_0A(help_font_init(bank*128+10)),
                .INIT_0B(help_font_init(bank*128+11)),
                .INIT_0C(help_font_init(bank*128+12)),
                .INIT_0D(help_font_init(bank*128+13)),
                .INIT_0E(help_font_init(bank*128+14)),
                .INIT_0F(help_font_init(bank*128+15)),
                .INIT_10(help_font_init(bank*128+16)),
                .INIT_11(help_font_init(bank*128+17)),
                .INIT_12(help_font_init(bank*128+18)),
                .INIT_13(help_font_init(bank*128+19)),
                .INIT_14(help_font_init(bank*128+20)),
                .INIT_15(help_font_init(bank*128+21)),
                .INIT_16(help_font_init(bank*128+22)),
                .INIT_17(help_font_init(bank*128+23)),
                .INIT_18(help_font_init(bank*128+24)),
                .INIT_19(help_font_init(bank*128+25)),
                .INIT_1A(help_font_init(bank*128+26)),
                .INIT_1B(help_font_init(bank*128+27)),
                .INIT_1C(help_font_init(bank*128+28)),
                .INIT_1D(help_font_init(bank*128+29)),
                .INIT_1E(help_font_init(bank*128+30)),
                .INIT_1F(help_font_init(bank*128+31)),
                .INIT_20(help_font_init(bank*128+32)),
                .INIT_21(help_font_init(bank*128+33)),
                .INIT_22(help_font_init(bank*128+34)),
                .INIT_23(help_font_init(bank*128+35)),
                .INIT_24(help_font_init(bank*128+36)),
                .INIT_25(help_font_init(bank*128+37)),
                .INIT_26(help_font_init(bank*128+38)),
                .INIT_27(help_font_init(bank*128+39)),
                .INIT_28(help_font_init(bank*128+40)),
                .INIT_29(help_font_init(bank*128+41)),
                .INIT_2A(help_font_init(bank*128+42)),
                .INIT_2B(help_font_init(bank*128+43)),
                .INIT_2C(help_font_init(bank*128+44)),
                .INIT_2D(help_font_init(bank*128+45)),
                .INIT_2E(help_font_init(bank*128+46)),
                .INIT_2F(help_font_init(bank*128+47)),
                .INIT_30(help_font_init(bank*128+48)),
                .INIT_31(help_font_init(bank*128+49)),
                .INIT_32(help_font_init(bank*128+50)),
                .INIT_33(help_font_init(bank*128+51)),
                .INIT_34(help_font_init(bank*128+52)),
                .INIT_35(help_font_init(bank*128+53)),
                .INIT_36(help_font_init(bank*128+54)),
                .INIT_37(help_font_init(bank*128+55)),
                .INIT_38(help_font_init(bank*128+56)),
                .INIT_39(help_font_init(bank*128+57)),
                .INIT_3A(help_font_init(bank*128+58)),
                .INIT_3B(help_font_init(bank*128+59)),
                .INIT_3C(help_font_init(bank*128+60)),
                .INIT_3D(help_font_init(bank*128+61)),
                .INIT_3E(help_font_init(bank*128+62)),
                .INIT_3F(help_font_init(bank*128+63)),
                .INIT_40(help_font_init(bank*128+64)),
                .INIT_41(help_font_init(bank*128+65)),
                .INIT_42(help_font_init(bank*128+66)),
                .INIT_43(help_font_init(bank*128+67)),
                .INIT_44(help_font_init(bank*128+68)),
                .INIT_45(help_font_init(bank*128+69)),
                .INIT_46(help_font_init(bank*128+70)),
                .INIT_47(help_font_init(bank*128+71)),
                .INIT_48(help_font_init(bank*128+72)),
                .INIT_49(help_font_init(bank*128+73)),
                .INIT_4A(help_font_init(bank*128+74)),
                .INIT_4B(help_font_init(bank*128+75)),
                .INIT_4C(help_font_init(bank*128+76)),
                .INIT_4D(help_font_init(bank*128+77)),
                .INIT_4E(help_font_init(bank*128+78)),
                .INIT_4F(help_font_init(bank*128+79)),
                .INIT_50(help_font_init(bank*128+80)),
                .INIT_51(help_font_init(bank*128+81)),
                .INIT_52(help_font_init(bank*128+82)),
                .INIT_53(help_font_init(bank*128+83)),
                .INIT_54(help_font_init(bank*128+84)),
                .INIT_55(help_font_init(bank*128+85)),
                .INIT_56(help_font_init(bank*128+86)),
                .INIT_57(help_font_init(bank*128+87)),
                .INIT_58(help_font_init(bank*128+88)),
                .INIT_59(help_font_init(bank*128+89)),
                .INIT_5A(help_font_init(bank*128+90)),
                .INIT_5B(help_font_init(bank*128+91)),
                .INIT_5C(help_font_init(bank*128+92)),
                .INIT_5D(help_font_init(bank*128+93)),
                .INIT_5E(help_font_init(bank*128+94)),
                .INIT_5F(help_font_init(bank*128+95)),
                .INIT_60(help_font_init(bank*128+96)),
                .INIT_61(help_font_init(bank*128+97)),
                .INIT_62(help_font_init(bank*128+98)),
                .INIT_63(help_font_init(bank*128+99)),
                .INIT_64(help_font_init(bank*128+100)),
                .INIT_65(help_font_init(bank*128+101)),
                .INIT_66(help_font_init(bank*128+102)),
                .INIT_67(help_font_init(bank*128+103)),
                .INIT_68(help_font_init(bank*128+104)),
                .INIT_69(help_font_init(bank*128+105)),
                .INIT_6A(help_font_init(bank*128+106)),
                .INIT_6B(help_font_init(bank*128+107)),
                .INIT_6C(help_font_init(bank*128+108)),
                .INIT_6D(help_font_init(bank*128+109)),
                .INIT_6E(help_font_init(bank*128+110)),
                .INIT_6F(help_font_init(bank*128+111)),
                .INIT_70(help_font_init(bank*128+112)),
                .INIT_71(help_font_init(bank*128+113)),
                .INIT_72(help_font_init(bank*128+114)),
                .INIT_73(help_font_init(bank*128+115)),
                .INIT_74(help_font_init(bank*128+116)),
                .INIT_75(help_font_init(bank*128+117)),
                .INIT_76(help_font_init(bank*128+118)),
                .INIT_77(help_font_init(bank*128+119)),
                .INIT_78(help_font_init(bank*128+120)),
                .INIT_79(help_font_init(bank*128+121)),
                .INIT_7A(help_font_init(bank*128+122)),
                .INIT_7B(help_font_init(bank*128+123)),
                .INIT_7C(help_font_init(bank*128+124)),
                .INIT_7D(help_font_init(bank*128+125)),
                .INIT_7E(help_font_init(bank*128+126)),
                .INIT_7F(help_font_init(bank*128+127))
    ) u_font (
        .doa(font_data[bank]), .dia(16'd0), .addra({glyph_code[6:0],dy[4:1]}),
        .bytea(1'b0), .bytewea(1'b0), .csa(1'b1), .wea(1'b0),
        .clka(clk), .rsta(1'b0), .ocea(1'b1),
        .dob(), .dib(16'd0), .addrb(11'd0), .byteb(1'b0), .byteweb(1'b0),
        .csb(1'b0), .web(1'b0), .clkb(clk), .rstb(1'b0), .oceb(1'b0)
    );
end endgenerate
assign glyph_bits = font_bank_q ? font_data[1] : font_data[0];
`endif
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        controls_ff1 <= 0; controls_ff2 <= 0; controls_frame <= 0;
        glyph_valid_q <= 0; glyph_col_q <= 0; heading_q <= 0; font_bank_q <= 0;
    end else begin
        controls_ff1 <= controls; controls_ff2 <= controls_ff1;
        if (x == 0 && y == 0) controls_frame <= controls_ff2;
        glyph_valid_q <= pre_x >= 64 && pre_x < 1088 &&
                         pre_y >= 48 && pre_y < 624;
        glyph_col_q <= dx[4:1];
        heading_q <= line == 0 || line == 3 || line == 8;
        font_bank_q <= glyph_code[7];
    end
end
always @* begin
    rgb = base_rgb;
    if (help_frame) begin
        rgb = 24'hF2EEE1;
        if (controls_frame[0])
            rgb = {background_pixel[15:11],background_pixel[15:13],
                   background_pixel[10:5],background_pixel[10:9],
                   background_pixel[4:0],background_pixel[4:2]};
        if (glyph_valid_q && glyph_bits[15-glyph_col_q])
            rgb = heading_q ? 24'h5B4525 : 24'h23302E;
    end
    if (!de) rgb = 24'h000000;
end
endmodule
`default_nettype wire
