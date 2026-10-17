`timescale 1ns / 1ps
`default_nettype none

// Three-clock video overlay. Name bytes are loaded by the subtitle FAT reader.
module museum_status_osd #(
    parameter integer SHOW_PERCENT = 0
)(
    input wire clk, input wire rst_n,
    input wire panel_enable,
    input wire hs_i, input wire vs_i, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    input wire [2:0] artifact, input wire [2:0] stage,
    input wire [2:0] effect,
    input wire [15:0] width_bcd, input wire [15:0] height_bcd,
    input wire zoom_2x, input wire manual_mode,
    input wire [1:0] speed_index,
    input wire [2:0] brightness_index, contrast_index, saturation_index, temperature_index,
    input wire name_ready,
    input wire name_wr_clk, input wire name_wr_en,
    input wire [10:0] name_wr_addr, input wire [7:0] name_wr_data,
    output reg hs_o, output reg vs_o, output reg de_o,
    output reg [10:0] x_o, output reg [9:0] y_o,
    output wire [23:0] rgb_o
);

wire [7:0] name_q;
reg [10:0] name_rd_addr;
subtitle_bitmap_ram #(.ADDR_WIDTH(11), .DEPTH(2048)) u_name_ram (
    .wr_clk(name_wr_clk), .wr_en(name_wr_en), .wr_addr(name_wr_addr),
    .wr_data(name_wr_data), .rd_clk(clk), .rd_addr(name_rd_addr),
    .rd_data(name_q)
);

reg ready_s1, ready_s2;
reg hs_s0,vs_s0,de_s0,hs_s1,vs_s1,de_s1;
reg [10:0] x_s0,x_s1;
reg [9:0] y_s0,y_s1;
reg [23:0] rgb_s0,rgb_s1,rgb_s2;
reg panel_s1,panel_s2,name_s1,name_s2,static_s1,static_s2;
reg [2:0] name_bit_s1,name_bit_s2;
reg [4:0] glyph_s0;
reg [3:0] glyph_row_s0,glyph_col_s0,glyph_col_s1;
wire [15:0] glyph_row_s1;
reg [4:0] ascii_s1;
reg [2:0] ascii_row_s1,ascii_col_s1;
reg glyph_hit_s2,ascii_hit_s2;

function [4:0] stage_glyph;
    input [2:0] value;
    input [1:0] slot;
    begin
        stage_glyph=0;
        case(value)
            0:case(slot) 0:stage_glyph=1; 1:stage_glyph=2; endcase // total view
            1:case(slot) 0:stage_glyph=3; 1:stage_glyph=4; endcase // full view
            2,3,4:case(slot) 0:stage_glyph=5; 1:stage_glyph=6; endcase
            5:case(slot) 0:stage_glyph=7; 1:stage_glyph=8;
                          2:stage_glyph=3; 3:stage_glyph=4; endcase
        endcase
    end
endfunction
function [15:0] chinese_row;
    input [4:0] glyph;
    input [3:0] row;
    begin
        case ({glyph,row})
            9'h010: chinese_row=16'h0810;
            9'h011: chinese_row=16'h0c20;
            9'h012: chinese_row=16'h0440;
            9'h013: chinese_row=16'h3ffc;
            9'h014: chinese_row=16'h2004;
            9'h015: chinese_row=16'h2004;
            9'h016: chinese_row=16'h2004;
            9'h017: chinese_row=16'h3ffc;
            9'h018: chinese_row=16'h2004;
            9'h019: chinese_row=16'h0180;
            9'h01a: chinese_row=16'h28c4;
            9'h01b: chinese_row=16'h4802;
            9'h01c: chinese_row=16'h8811;
            9'h01d: chinese_row=16'h0fe0;
            9'h020: chinese_row=16'h4440;
            9'h021: chinese_row=16'h44ff;
            9'h022: chinese_row=16'h4500;
            9'h023: chinese_row=16'h4560;
            9'h024: chinese_row=16'h4638;
            9'h025: chinese_row=16'h000c;
            9'h026: chinese_row=16'h3ff8;
            9'h027: chinese_row=16'h2008;
            9'h028: chinese_row=16'h2108;
            9'h029: chinese_row=16'h2188;
            9'h02a: chinese_row=16'h2389;
            9'h02b: chinese_row=16'h0681;
            9'h02c: chinese_row=16'h1881;
            9'h02d: chinese_row=16'he07e;
            9'h030: chinese_row=16'h0300;
            9'h031: chinese_row=16'h0780;
            9'h032: chinese_row=16'h0cc0;
            9'h033: chinese_row=16'h0860;
            9'h034: chinese_row=16'h3030;
            9'h035: chinese_row=16'h601c;
            9'h036: chinese_row=16'hdff6;
            9'h037: chinese_row=16'h0100;
            9'h038: chinese_row=16'h0100;
            9'h039: chinese_row=16'h3ff8;
            9'h03a: chinese_row=16'h0100;
            9'h03b: chinese_row=16'h0100;
            9'h03c: chinese_row=16'h0100;
            9'h03d: chinese_row=16'h7ffc;
            9'h040: chinese_row=16'h0860;
            9'h041: chinese_row=16'h31fe;
            9'h042: chinese_row=16'hf106;
            9'h043: chinese_row=16'h0d06;
            9'h044: chinese_row=16'h7906;
            9'h045: chinese_row=16'h71fe;
            9'h046: chinese_row=16'h5106;
            9'h047: chinese_row=16'h3906;
            9'h048: chinese_row=16'h69fe;
            9'h049: chinese_row=16'h0856;
            9'h04a: chinese_row=16'h38d0;
            9'h04b: chinese_row=16'h6c91;
            9'h04c: chinese_row=16'h0c91;
            9'h04d: chinese_row=16'h0b1b;
            9'h04e: chinese_row=16'h3a0e;
            9'h051: chinese_row=16'h1000;
            9'h052: chinese_row=16'h23fe;
            9'h053: chinese_row=16'h2222;
            9'h054: chinese_row=16'h4a22;
            9'h055: chinese_row=16'hd222;
            9'h056: chinese_row=16'hf222;
            9'h057: chinese_row=16'h23fe;
            9'h058: chinese_row=16'h4222;
            9'h059: chinese_row=16'hfa22;
            9'h05a: chinese_row=16'h0222;
            9'h05b: chinese_row=16'h0222;
            9'h05c: chinese_row=16'h3a22;
            9'h05d: chinese_row=16'hc3fe;
            9'h05e: chinese_row=16'h0202;
            9'h060: chinese_row=16'h0420;
            9'h061: chinese_row=16'h0420;
            9'h062: chinese_row=16'hffff;
            9'h063: chinese_row=16'h0420;
            9'h064: chinese_row=16'h0420;
            9'h066: chinese_row=16'h7ffc;
            9'h067: chinese_row=16'h0404;
            9'h068: chinese_row=16'h0404;
            9'h069: chinese_row=16'h0404;
            9'h06a: chinese_row=16'h0404;
            9'h06b: chinese_row=16'h0404;
            9'h06c: chinese_row=16'h04f8;
            9'h06d: chinese_row=16'h0400;
            9'h06e: chinese_row=16'h0400;
            9'h071: chinese_row=16'h1ffc;
            9'h072: chinese_row=16'h1004;
            9'h073: chinese_row=16'h1ffc;
            9'h074: chinese_row=16'h1004;
            9'h075: chinese_row=16'h1ffc;
            9'h077: chinese_row=16'hffff;
            9'h078: chinese_row=16'h2100;
            9'h079: chinese_row=16'h3ffe;
            9'h07a: chinese_row=16'h2142;
            9'h07b: chinese_row=16'h3f24;
            9'h07c: chinese_row=16'h2118;
            9'h07d: chinese_row=16'hffbc;
            9'h07e: chinese_row=16'h01c3;
            9'h081: chinese_row=16'h2100;
            9'h082: chinese_row=16'h4300;
            9'h083: chinese_row=16'h53fc;
            9'h084: chinese_row=16'hb70c;
            9'h085: chinese_row=16'h2518;
            9'h086: chinese_row=16'hc8b0;
            9'h087: chinese_row=16'h4060;
            9'h088: chinese_row=16'h83b8;
            9'h089: chinese_row=16'h8c06;
            9'h08a: chinese_row=16'hf1c0;
            9'h08b: chinese_row=16'h0038;
            9'h08c: chinese_row=16'h7600;
            9'h08d: chinese_row=16'h81e0;
            9'h08e: chinese_row=16'h0018;
            9'h090: chinese_row=16'h1000;
            9'h091: chinese_row=16'h11fe;
            9'h092: chinese_row=16'h1000;
            9'h093: chinese_row=16'h7c00;
            9'h094: chinese_row=16'h11ff;
            9'h095: chinese_row=16'h1020;
            9'h096: chinese_row=16'h3c20;
            9'h097: chinese_row=16'h36a4;
            9'h098: chinese_row=16'h5126;
            9'h099: chinese_row=16'h5122;
            9'h09a: chinese_row=16'h1222;
            9'h09b: chinese_row=16'h1223;
            9'h09c: chinese_row=16'h1421;
            9'h09d: chinese_row=16'h11e0;
            9'h0a0: chinese_row=16'h0120;
            9'h0a1: chinese_row=16'h8330;
            9'h0a2: chinese_row=16'h4210;
            9'h0a3: chinese_row=16'h67ff;
            9'h0a4: chinese_row=16'h2e10;
            9'h0a5: chinese_row=16'h0e10;
            9'h0a6: chinese_row=16'h1bfe;
            9'h0a7: chinese_row=16'h0210;
            9'h0a8: chinese_row=16'h2210;
            9'h0a9: chinese_row=16'h63fe;
            9'h0aa: chinese_row=16'h4210;
            9'h0ab: chinese_row=16'h4210;
            9'h0ac: chinese_row=16'h8210;
            9'h0ad: chinese_row=16'h83ff;
            9'h0ae: chinese_row=16'h0200;
            9'h0b0: chinese_row=16'h7cfe;
            9'h0b1: chinese_row=16'h4482;
            9'h0b2: chinese_row=16'h4482;
            9'h0b3: chinese_row=16'h4482;
            9'h0b4: chinese_row=16'h44fe;
            9'h0b5: chinese_row=16'h7c82;
            9'h0b6: chinese_row=16'h4482;
            9'h0b7: chinese_row=16'h4482;
            9'h0b8: chinese_row=16'h44fe;
            9'h0b9: chinese_row=16'h4482;
            9'h0ba: chinese_row=16'h7d02;
            9'h0bb: chinese_row=16'h4302;
            9'h0bc: chinese_row=16'h0202;
            9'h0bd: chinese_row=16'h043e;
            9'h0c0: chinese_row=16'h0100;
            9'h0c1: chinese_row=16'h0080;
            9'h0c2: chinese_row=16'h7fff;
            9'h0c4: chinese_row=16'h1ff8;
            9'h0c5: chinese_row=16'h1008;
            9'h0c6: chinese_row=16'h1ff8;
            9'h0c8: chinese_row=16'h7ffe;
            9'h0c9: chinese_row=16'h4002;
            9'h0ca: chinese_row=16'h07e0;
            9'h0cb: chinese_row=16'h0421;
            9'h0cc: chinese_row=16'h0421;
            9'h0cd: chinese_row=16'h1821;
            9'h0ce: chinese_row=16'h703e;
            9'h0d0: chinese_row=16'h0180;
            9'h0d1: chinese_row=16'hffff;
            9'h0d3: chinese_row=16'h1ff8;
            9'h0d4: chinese_row=16'h1008;
            9'h0d5: chinese_row=16'h1ff8;
            9'h0d7: chinese_row=16'h7ffe;
            9'h0d8: chinese_row=16'h4002;
            9'h0d9: chinese_row=16'h4fe2;
            9'h0da: chinese_row=16'h4822;
            9'h0db: chinese_row=16'h4fe2;
            9'h0dc: chinese_row=16'h4802;
            9'h0dd: chinese_row=16'h403e;
            9'h0e0: chinese_row=16'h0004;
            9'h0e1: chinese_row=16'h0004;
            9'h0e2: chinese_row=16'h7e04;
            9'h0e3: chinese_row=16'h0204;
            9'h0e4: chinese_row=16'h42ff;
            9'h0e5: chinese_row=16'h2604;
            9'h0e6: chinese_row=16'h3484;
            9'h0e7: chinese_row=16'h1c44;
            9'h0e8: chinese_row=16'h0c44;
            9'h0e9: chinese_row=16'h0c24;
            9'h0ea: chinese_row=16'h1604;
            9'h0eb: chinese_row=16'h3204;
            9'h0ec: chinese_row=16'h6104;
            9'h0ed: chinese_row=16'h8078;
            9'h0f0: chinese_row=16'h4080;
            9'h0f1: chinese_row=16'h4080;
            9'h0f2: chinese_row=16'h4080;
            9'h0f3: chinese_row=16'h4082;
            9'h0f4: chinese_row=16'h4084;
            9'h0f5: chinese_row=16'h7e98;
            9'h0f6: chinese_row=16'h40b0;
            9'h0f7: chinese_row=16'h40c0;
            9'h0f8: chinese_row=16'h4080;
            9'h0f9: chinese_row=16'h4082;
            9'h0fa: chinese_row=16'h4082;
            9'h0fb: chinese_row=16'h4682;
            9'h0fc: chinese_row=16'h7882;
            9'h0fd: chinese_row=16'h60fc;
            9'h100: chinese_row=16'h3ffc;
            9'h101: chinese_row=16'h0c18;
            9'h102: chinese_row=16'h0360;
            9'h103: chinese_row=16'h00c0;
            9'h104: chinese_row=16'h7ffe;
            9'h105: chinese_row=16'h0642;
            9'h106: chinese_row=16'h1c44;
            9'h107: chinese_row=16'h63c0;
            9'h108: chinese_row=16'h0100;
            9'h109: chinese_row=16'h7fff;
            9'h10a: chinese_row=16'h0380;
            9'h10b: chinese_row=16'h0d60;
            9'h10c: chinese_row=16'h3118;
            9'h10d: chinese_row=16'hc107;
            9'h10e: chinese_row=16'h0100;
            9'h110: chinese_row=16'h0e00;
            9'h111: chinese_row=16'hf000;
            9'h112: chinese_row=16'h10fe;
            9'h113: chinese_row=16'h1082;
            9'h114: chinese_row=16'hfe82;
            9'h115: chinese_row=16'h1082;
            9'h116: chinese_row=16'h3082;
            9'h117: chinese_row=16'h3882;
            9'h118: chinese_row=16'h7c82;
            9'h119: chinese_row=16'h5682;
            9'h11a: chinese_row=16'hd082;
            9'h11b: chinese_row=16'h9082;
            9'h11c: chinese_row=16'h10fe;
            9'h11d: chinese_row=16'h1082;
            9'h120: chinese_row=16'h0100;
            9'h121: chinese_row=16'h0080;
            9'h122: chinese_row=16'h0080;
            9'h123: chinese_row=16'hffff;
            9'h124: chinese_row=16'h1008;
            9'h125: chinese_row=16'h1008;
            9'h126: chinese_row=16'h0810;
            9'h127: chinese_row=16'h0810;
            9'h128: chinese_row=16'h0420;
            9'h129: chinese_row=16'h0640;
            9'h12a: chinese_row=16'h0380;
            9'h12b: chinese_row=16'h0380;
            9'h12c: chinese_row=16'h0660;
            9'h12d: chinese_row=16'h381c;
            9'h12e: chinese_row=16'hc007;
            9'h130: chinese_row=16'h1080;
            9'h131: chinese_row=16'h5100;
            9'h132: chinese_row=16'h51fe;
            9'h133: chinese_row=16'h7a52;
            9'h134: chinese_row=16'h9252;
            9'h135: chinese_row=16'h9452;
            9'h136: chinese_row=16'h9064;
            9'h137: chinese_row=16'h1ca4;
            9'h138: chinese_row=16'h70a4;
            9'h139: chinese_row=16'hd164;
            9'h13a: chinese_row=16'h1244;
            9'h13b: chinese_row=16'h1084;
            9'h13c: chinese_row=16'h1184;
            9'h13d: chinese_row=16'h1238;
            9'h13e: chinese_row=16'h1000;
            // 自、动、手: native 16-pixel glyphs in the existing font ROM.
            9'h140: chinese_row=16'h0400;
            9'h141: chinese_row=16'h1ff0;
            9'h142: chinese_row=16'h1010;
            9'h143: chinese_row=16'h1010;
            9'h144: chinese_row=16'h1010;
            9'h145: chinese_row=16'h1ff0;
            9'h146: chinese_row=16'h1010;
            9'h147: chinese_row=16'h1010;
            9'h148: chinese_row=16'h1ff0;
            9'h149: chinese_row=16'h1010;
            9'h14a: chinese_row=16'h1010;
            9'h14b: chinese_row=16'h1010;
            9'h14c: chinese_row=16'h1ff0;
            9'h14d: chinese_row=16'h1010;
            9'h150: chinese_row=16'h7c40;
            9'h151: chinese_row=16'h0040;
            9'h152: chinese_row=16'h01fc;
            9'h153: chinese_row=16'h0044;
            9'h154: chinese_row=16'hfe44;
            9'h155: chinese_row=16'h2044;
            9'h156: chinese_row=16'h2044;
            9'h157: chinese_row=16'h2084;
            9'h158: chinese_row=16'h4884;
            9'h159: chinese_row=16'h4484;
            9'h15a: chinese_row=16'hfd04;
            9'h15b: chinese_row=16'h4504;
            9'h15c: chinese_row=16'h0228;
            9'h15d: chinese_row=16'h0410;
            9'h160: chinese_row=16'h3f00;
            9'h161: chinese_row=16'h0100;
            9'h162: chinese_row=16'h0100;
            9'h163: chinese_row=16'h3ff8;
            9'h164: chinese_row=16'h0100;
            9'h165: chinese_row=16'h0100;
            9'h166: chinese_row=16'h0100;
            9'h167: chinese_row=16'hfffe;
            9'h168: chinese_row=16'h0100;
            9'h169: chinese_row=16'h0100;
            9'h16a: chinese_row=16'h0100;
            9'h16b: chinese_row=16'h0100;
            9'h16c: chinese_row=16'h0500;
            9'h16d: chinese_row=16'h0200;
            default: chinese_row=16'd0;
        endcase
    end
endfunction
function [4:0] ascii_code;
    input [3:0] slot;
    input [15:0] w,h;
    begin
        case(slot)
            0:ascii_code={1'b0,w[15:12]};
            1:ascii_code={1'b0,w[11:8]};
            2:ascii_code={1'b0,w[7:4]};
            3:ascii_code={1'b0,w[3:0]};
            4:ascii_code=5'd16; // x
            5:ascii_code={1'b0,h[15:12]};
            6:ascii_code={1'b0,h[11:8]};
            7:ascii_code={1'b0,h[7:4]};
            default:ascii_code={1'b0,h[3:0]};
        endcase
    end
endfunction
function [34:0] ascii_bitmap;
    input [4:0] code;
    begin
        case(code)
            0:ascii_bitmap={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
            1:ascii_bitmap={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            2:ascii_bitmap={5'b01110,5'b10001,5'b00001,5'b00110,5'b01000,5'b10000,5'b11111};
            3:ascii_bitmap={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
            4:ascii_bitmap={5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010,5'b00010};
            5:ascii_bitmap={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
            6:ascii_bitmap={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
            7:ascii_bitmap={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
            8:ascii_bitmap={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
            9:ascii_bitmap={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
            16:ascii_bitmap={5'b00000,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b00000};
            17:ascii_bitmap={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b11111};
            18:ascii_bitmap={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            19:ascii_bitmap={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
            20:ascii_bitmap={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
            21:ascii_bitmap={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
            22:ascii_bitmap={5'b01110,5'b10001,5'b10000,5'b10000,5'b10000,5'b10001,5'b01110}; // C
            23:ascii_bitmap={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // U
            24:ascii_bitmap={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110}; // S
            25:ascii_bitmap={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100}; // T
            26:ascii_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110}; // B
            27:ascii_bitmap={5'b11001,5'b11010,5'b00010,5'b00100,5'b01000,5'b01011,5'b10011}; // %
            28:ascii_bitmap={5'b00000,5'b00100,5'b00100,5'b11111,5'b00100,5'b00100,5'b00000}; // +
            29:ascii_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000}; // P
            30:ascii_bitmap={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110}; // D
            default:ascii_bitmap=35'd0;
        endcase
    end
endfunction
function [4:0] ascii_row;
    input [4:0] code;
    input [2:0] row;
    reg [34:0] bits;
    begin
        bits=ascii_bitmap(code);
        case(row)
            0:ascii_row=bits[34:30];
            1:ascii_row=bits[29:25];
            2:ascii_row=bits[24:20];
            3:ascii_row=bits[19:15];
            4:ascii_row=bits[14:10];
            5:ascii_row=bits[9:5];
            default:ascii_row=bits[4:0];
        endcase
    end
endfunction
wire [4:0] ascii_bits;
wire [2:0] ascii_read_row;
reg [4:0] chosen_ascii;
// Keep the same one-clock font lookup; a ROM frees routing resources for
// the MAIN-5 controls without changing any glyph or pixel latency.
    function [255:0] font_init;
        input [5:0] chunk;
        integer row_index;
        begin
            for (row_index=0; row_index<16; row_index=row_index+1)
                font_init[row_index*16 +: 16]=chunk<32 ?
                    chinese_row(chunk[4:0],row_index[3:0]) :
                    {11'd0,ascii_row({chunk[3:0],row_index[3]},row_index[2:0])};
        end
    endfunction
generate if (SHOW_PERCENT) begin : g_font_rom
`ifdef SIM
    reg [15:0] row_q;
    always @(posedge clk) row_q<=chinese_row(glyph_s0,glyph_row_s0);
    assign glyph_row_s1=row_q;
    assign ascii_bits=ascii_row(ascii_s1,ascii_row_s1);
`else
    wire [15:0] ascii_word;
    assign ascii_bits=ascii_word[4:0];
    EG_PHY_BRAM32K #(
        .MODE("DP16K"), .DATA_WIDTH_A("16"), .DATA_WIDTH_B("16"),
        .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .INIT_00(font_init(0)), .INIT_01(font_init(1)),
        .INIT_02(font_init(2)), .INIT_03(font_init(3)),
        .INIT_04(font_init(4)), .INIT_05(font_init(5)),
        .INIT_06(font_init(6)), .INIT_07(font_init(7)),
        .INIT_08(font_init(8)), .INIT_09(font_init(9)),
        .INIT_0A(font_init(10)), .INIT_0B(font_init(11)),
        .INIT_0C(font_init(12)), .INIT_0D(font_init(13)),
        .INIT_0E(font_init(14)), .INIT_0F(font_init(15)),
        .INIT_10(font_init(16)), .INIT_11(font_init(17)),
        .INIT_12(font_init(18)), .INIT_13(font_init(19)),
        .INIT_14(font_init(20)), .INIT_15(font_init(21)),
        .INIT_16(font_init(22)),
        .INIT_20(font_init(32)), .INIT_21(font_init(33)),
        .INIT_22(font_init(34)), .INIT_23(font_init(35)),
        .INIT_24(font_init(36)), .INIT_25(font_init(37)),
        .INIT_26(font_init(38)), .INIT_27(font_init(39)),
        .INIT_28(font_init(40)), .INIT_29(font_init(41)),
        .INIT_2A(font_init(42)), .INIT_2B(font_init(43)),
        .INIT_2C(font_init(44)), .INIT_2D(font_init(45)),
        .INIT_2E(font_init(46)), .INIT_2F(font_init(47))
    ) u_rom (
        .doa(glyph_row_s1), .dia(16'd0), .addra({2'b00,glyph_s0,glyph_row_s0}),
        .bytea(1'b0), .bytewea(1'b0), .csa(1'b1), .wea(1'b0),
        .clka(clk), .rsta(1'b0), .ocea(1'b1),
        .dob(ascii_word), .dib(16'd0), .addrb({3'b010,chosen_ascii,ascii_read_row}),
        .byteb(1'b0), .byteweb(1'b0),
        .csb(1'b1), .web(1'b0), .clkb(clk), .rstb(1'b0), .oceb(1'b1)
    );
`endif
end else begin : g_font_logic
    reg [15:0] row_q;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) row_q<=0;
        else row_q<=chinese_row(glyph_s0,glyph_row_s0);
    assign glyph_row_s1=row_q;
    assign ascii_bits=ascii_row(ascii_s1,ascii_row_s1);
end endgenerate

reg ascii_valid_s1;
reg [3:0] slot;
reg [10:0] local_x;
reg [3:0] ascii_y_s0;
reg [6:0] ascii_name_x_s0;
reg [7:0] ascii_size_x_s0;
reg [2:0] ascii_col_s0;
reg ascii_x_valid_s0;
wire [2:0] ascii_x_low = SHOW_PERCENT && y_i>=56 ? x_i-11'd12 :
                         x_i<202 ? x_i-11'd22 :
                         x_i<332 ? x_i-11'd202 : x_i-11'd332;
wire [3:0] local_y = ascii_y_s0;
assign ascii_read_row=local_y[2:0];
// Constant BCD tables: percentages are presentation only, no pixel dividers.
function [11:0] percent_bcd;
    input [1:0] field;
    input [2:0] index;
    begin
        percent_bcd=0;
        case(field)
            0:case(index) 0,6:percent_bcd=12'h019; 1,5:percent_bcd=12'h013;
                          2,4:percent_bcd=12'h006; endcase
            1:case(index) 0:percent_bcd=12'h050; 1:percent_bcd=12'h075;
                          2:percent_bcd=12'h100; 3:percent_bcd=12'h125;
                          4:percent_bcd=12'h150; endcase
            2:case(index) 1:percent_bcd=12'h050; 2:percent_bcd=12'h075;
                          3:percent_bcd=12'h100; 4:percent_bcd=12'h125;
                          5:percent_bcd=12'h150; endcase
            3:case(index) 0,6:percent_bcd=12'h100; 1,5:percent_bcd=12'h067;
                          2,4:percent_bcd=12'h033; endcase
        endcase
    end
endfunction
reg [11:0] percent_digits_s0;
reg [4:0] percent_label_s0, percent_sign_s0;
reg [3:0] percent_slot_s0;
wire [10:0] percent_x = x_i-11'd12;
wire [1:0] percent_field = percent_x[8:7];
reg [2:0] percent_index;
always @* begin
    case(percent_field)
        0:percent_index=brightness_index;
        1:percent_index=contrast_index;
        2:percent_index=saturation_index;
        default:percent_index=temperature_index;
    endcase
end
always @(posedge clk) begin
    percent_digits_s0<=percent_bcd(percent_field,percent_index);
    percent_label_s0<=percent_field==0 ? 26 : percent_field==1 ? 22 : percent_field==2 ? 24 : 25;
    percent_sign_s0<=(percent_field==0 || percent_field==3) && percent_index!=3 ?
                     (percent_index<3 ? 20 : 28) : 31;
    percent_slot_s0<=percent_x[6:3];
end
always @(*) begin
    chosen_ascii=5'd31; slot=0;
    local_x=0;
    if (SHOW_PERCENT && x_s0>=12 && x_s0<492 && y_s0>=56 && y_s0<64) begin
        case(percent_slot_s0)
            0:chosen_ascii=percent_label_s0;
            2:chosen_ascii=percent_sign_s0;
            3:chosen_ascii=percent_digits_s0[11:8]==0 ? 31 : {1'b0,percent_digits_s0[11:8]};
            4:chosen_ascii=percent_digits_s0[11:4]==0 ? 31 : {1'b0,percent_digits_s0[7:4]};
            5:chosen_ascii={1'b0,percent_digits_s0[3:0]};
            6:chosen_ascii=27;
        endcase
    end else if (x_s0>=22 && x_s0<182 && y_s0>=12 && y_s0<28 && !ready_s2) begin
        local_x={4'd0,ascii_name_x_s0};
        slot=local_x[6:3];
        case(slot)
            4:chosen_ascii={2'b00,artifact};
        endcase
    end else if (x_s0>=202 && x_s0<266 && y_s0>=12 && y_s0<28) begin
        local_x={3'd0,ascii_size_x_s0};
        if (stage>=2 && stage<=4 && local_x[6:3]==4)
            chosen_ascii=stage-1'b1;
    end else if (x_s0>=22 && x_s0<70 &&
                 y_s0>=32 && y_s0<48) begin
        local_x={4'd0,ascii_name_x_s0};
        if (effect==3'd4) begin
            case(local_x[5:3])
                0:chosen_ascii=5'd22; // C
                1:chosen_ascii=5'd23; // U
                2:chosen_ascii=5'd24; // S
                3:chosen_ascii=5'd25; // T
                4:chosen_ascii=5'd18; // O
                5:chosen_ascii=5'd19; // M
            endcase
        end
    end else if (x_s0>=202 && x_s0<274 && y_s0>=32 && y_s0<40) begin
        local_x={3'd0,ascii_size_x_s0};
        chosen_ascii=ascii_code(ascii_size_x_s0[6:3],width_bcd,height_bcd);
    end else if (x_s0>=332 && x_s0<380 && y_s0>=32 && y_s0<40) begin
        local_x=x_s0-332;
        case(local_x[5:3])
            0:chosen_ascii=5'd17; // Z
            1:chosen_ascii=5'd18; // O
            2:chosen_ascii=5'd18;
            3:chosen_ascii=5'd19; // M
            4:chosen_ascii=zoom_2x ? 5'd2 : 5'd1;
            5:chosen_ascii=5'd16; // x
        endcase
    end else if (SHOW_PERCENT && x_s0>=412 && x_s0<452 && y_s0>=32 && y_s0<40) begin
        local_x=x_s0-412;
        case(local_x[5:3])
            0:chosen_ascii=5'd24; // S
            1:chosen_ascii=5'd29; // P
            2:chosen_ascii=5'd30; // D
            3:chosen_ascii={3'd0,speed_index}+5'd1;
            4:chosen_ascii=5'd16; // x
        endcase
    end
end

reg [4:0] early_glyph;
reg [3:0] early_row,early_col;
always @(*) begin
    early_glyph=0;
    early_row=0;
    early_col=0;
    // Chinese and TF names retain every source pixel: 8x8 decimation loses strokes.
    if (x_i>=22 && x_i<182 && y_i>=12 && y_i<28 && !ready_s2) begin
        early_glyph=(x_i<38) ? 5'd18 : (x_i<54) ? 5'd19 : 5'd0;
        early_row=y_i-12;
        early_col=x_i-22;
    end else if (x_i>=202 && x_i<266 && y_i>=12 && y_i<28) begin
        early_glyph=stage_glyph(stage,(x_i-202)>>4);
        early_row=y_i-12;
        early_col=x_i-202;
    end else if (SHOW_PERCENT && x_i>=332 && x_i<364 && y_i>=12 && y_i<28) begin
        early_glyph=x_i<348 ? (manual_mode ? 5'd22 : 5'd20) : 5'd21;
        early_row=y_i-12;
        early_col=x_i-332;
    end else if (x_i>=22 && x_i<70 && y_i>=32 && y_i<48) begin
        case(effect)
            0:early_glyph=(x_i<38) ? 5'd9 : (x_i<54) ? 5'd10 : 5'd0; // 标准
            1:early_glyph=(x_i<38) ? 5'd11 : (x_i<54) ? 5'd12 : 5'd0; // 明亮
            2:early_glyph=(x_i<38) ? 5'd13 : (x_i<54) ? 5'd14 : 5'd15; // 高对比
            3:early_glyph=(x_i<38) ? 5'd16 : (x_i<54) ? 5'd17 : 5'd0; // 柔和
        endcase
        early_row=y_i-32;
        early_col=x_i-22;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready_s1<=0; ready_s2<=0;
        hs_s0<=1;vs_s0<=1;de_s0<=0;x_s0<=0;y_s0<=0;rgb_s0<=0;
        hs_s1<=1;vs_s1<=1;de_s1<=0;x_s1<=0;y_s1<=0;rgb_s1<=0;
        hs_o<=1;vs_o<=1;de_o<=0;x_o<=0;y_o<=0;rgb_s2<=0;
        panel_s1<=0;panel_s2<=0;name_s1<=0;name_s2<=0;
        static_s1<=0;static_s2<=0;name_bit_s1<=0;name_bit_s2<=0;
        glyph_s0<=0;glyph_row_s0<=0;glyph_col_s0<=0;
        glyph_col_s1<=0;
        ascii_s1<=31;ascii_row_s1<=0;ascii_col_s1<=0;ascii_valid_s1<=0;
        ascii_y_s0<=0;
        ascii_name_x_s0<=0;ascii_size_x_s0<=0;
        ascii_col_s0<=0;ascii_x_valid_s0<=0;
        glyph_hit_s2<=0;ascii_hit_s2<=0;name_rd_addr<=0;
    end else begin
        ready_s1<=name_ready; ready_s2<=ready_s1;
        glyph_s0<=early_glyph; glyph_row_s0<=early_row;
        glyph_col_s0<=early_col;
        hs_s0<=hs_i;vs_s0<=vs_i;de_s0<=de_i;
        x_s0<=x_i;y_s0<=y_i;rgb_s0<=rgb_i;
        // Compute text-row coordinates in the existing s0 stage before region
        // selection. Output latency remains three clocks.
        ascii_y_s0<=y_i<28 ? y_i-10'd12 : y_i<48 ? y_i-10'd32 : y_i-10'd56;
        ascii_name_x_s0<=x_i-11'd22;
        ascii_size_x_s0<=x_i-11'd202;
        ascii_col_s0<=ascii_x_low-3'd1;
        ascii_x_valid_s0<=ascii_x_low>=1 && ascii_x_low<6;
        hs_s1<=hs_s0;vs_s1<=vs_s0;de_s1<=de_s0;
        x_s1<=x_s0;y_s1<=y_s0;rgb_s1<=rgb_s0;
        panel_s1<=panel_enable && de_s0 && x_s0>=12 && x_s0<492 &&
                  y_s0>=8 && y_s0<(SHOW_PERCENT ? 68 : 52);
        name_s1<=de_s0 && ready_s2 && x_s0>=22 && x_s0<182 &&
                 y_s0>=12 && y_s0<28;
        if (x_s0>=22 && x_s0<182 && y_s0>=12 && y_s0<28)
            name_rd_addr<=({artifact,8'd0}+{artifact,6'd0})+
                          ((y_s0-12)<<4)+((y_s0-12)<<2)+((x_s0-22)>>3);
        name_bit_s1<=3'd7-(x_s0-11'd22);
        static_s1<=glyph_s0!=0;
        glyph_col_s1<=glyph_col_s0;
        ascii_s1<=chosen_ascii;
        ascii_valid_s1<=chosen_ascii!=31 && ascii_x_valid_s0 && local_y[3:0]<7;
        ascii_row_s1<=local_y[2:0];
        ascii_col_s1<=ascii_col_s0;
        hs_o<=hs_s1;vs_o<=vs_s1;de_o<=de_s1;
        x_o<=x_s1;y_o<=y_s1;rgb_s2<=rgb_s1;
        panel_s2<=panel_s1;name_s2<=name_s1;
        static_s2<=static_s1;name_bit_s2<=name_bit_s1;
        glyph_hit_s2<=glyph_row_s1[15-glyph_col_s1];
        ascii_hit_s2<=ascii_valid_s1 && ascii_bits[4-ascii_col_s1];
    end
end
wire text_hit = (name_s2 && name_q[name_bit_s2]) ||
                (static_s2 && glyph_hit_s2) || ascii_hit_s2;
assign rgb_o=!de_o ? 24'd0 :
             !panel_s2 ? rgb_s2 :
             text_hit ? 24'hffffff :
             {1'b0,rgb_s2[23:17],1'b0,rgb_s2[15:9],1'b0,rgb_s2[7:1]};
endmodule

`default_nettype wire
