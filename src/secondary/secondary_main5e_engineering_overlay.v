`timescale 1ns / 1ps
`default_nettype none

// SW4 engineering monitor. Values are hexadecimal snapshots from completed
// MBP1 packets; normal media pixels continue scanning underneath this page.
module secondary_main5e_engineering_overlay (
    input wire clk,
    input wire rst_n,
    input wire de,
    input wire [10:0] x,
    input wire [9:0] y,
    input wire [10:0] pre_x,
    input wire [9:0] pre_y,
    input wire [23:0] base_rgb,
    input wire enable_50m,
    input wire link_50m,
    input wire [127:0] heartbeat_50m,
    input wire [95:0] display_50m,
    input wire [127:0] diagnostic_50m,
    input wire [7:0] result_50m,
    output reg [23:0] rgb
);
reg enable_q1, enable_q2, enable_frame;
reg link_q1, link_q2, link_frame;
reg [127:0] hb_q1, hb_q2, hb_frame;
reg [95:0] dis_q1, dis_q2, dis_frame;
reg [127:0] diag_q1, diag_q2, diag_frame;
reg [7:0] result_q1, result_q2, result_frame;
reg title_pixel, label_pixel;
reg [8:0] value_pixels;

function [34:0] glyph;
    input [7:0] c;
    begin
        case (c)
            "A": glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "B": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
            "C": glyph={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
            "D": glyph={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
            "E": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
            "F": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
            "G": glyph={5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
            "H": glyph={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "I": glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
            "K": glyph={5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
            "L": glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
            "M": glyph={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
            "N": glyph={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
            "O": glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "P": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
            "R": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
            "S": glyph={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
            "T": glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
            "U": glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "X": glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
            "Y": glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
            "Z": glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b11111};
            "0": glyph={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
            "1": glyph={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            "2": glyph={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
            "3": glyph={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
            "4": glyph={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
            "5": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
            "6": glyph={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
            "7": glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
            "8": glyph={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
            "9": glyph={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
            default: glyph=0;
        endcase
    end
endfunction
function [7:0] label_char;
    input [4:0] id;
    input [3:0] index;
    begin
        label_char=" ";
        case (id)
             0: case(index) 0:label_char="M";1:label_char="A";2:label_char="I";3:label_char="N";5:label_char="S";6:label_char="T";7:label_char="A";8:label_char="T";9:label_char="U";10:label_char="S"; endcase
             1: case(index) 0:label_char="L";1:label_char="I";2:label_char="N";3:label_char="K"; endcase
             2: case(index) 0:label_char="E";1:label_char="M";2:label_char="E";3:label_char="R";4:label_char="G";5:label_char="E";6:label_char="N";7:label_char="C";8:label_char="Y"; endcase
             3: case(index) 0:label_char="A";1:label_char="R";2:label_char="T";3:label_char="I";4:label_char="F";5:label_char="A";6:label_char="C";7:label_char="T"; endcase
             4: case(index) 0:label_char="P";1:label_char="H";2:label_char="A";3:label_char="S";4:label_char="E"; endcase
             5: case(index) 0:label_char="P";1:label_char="R";2:label_char="E";3:label_char="L";4:label_char="O";5:label_char="A";6:label_char="D"; endcase
             6: case(index) 0:label_char="C";1:label_char="A";2:label_char="C";3:label_char="H";4:label_char="E"; endcase
             7: case(index) 0:label_char="P";1:label_char="L";2:label_char="A";3:label_char="Y"; endcase
             8: case(index) 0:label_char="P";1:label_char="R";2:label_char="E";3:label_char="S";4:label_char="E";5:label_char="T"; endcase
             9: case(index) 0:label_char="B";1:label_char="R";2:label_char="I";3:label_char="G";4:label_char="H";5:label_char="T"; endcase
            10: case(index) 0:label_char="C";1:label_char="O";2:label_char="N";3:label_char="T";4:label_char="R";5:label_char="A";6:label_char="S";7:label_char="T"; endcase
            11: case(index) 0:label_char="S";1:label_char="A";2:label_char="T";3:label_char="U";4:label_char="R";5:label_char="A";6:label_char="T";7:label_char="I";8:label_char="O";9:label_char="N"; endcase
            12: case(index) 0:label_char="T";1:label_char="E";2:label_char="M";3:label_char="P"; endcase
            13: case(index) 0:label_char="Z";1:label_char="O";2:label_char="O";3:label_char="M"; endcase
            14: case(index) 0:label_char="P";1:label_char="A";2:label_char="N";4:label_char="X"; endcase
            15: case(index) 0:label_char="P";1:label_char="A";2:label_char="N";4:label_char="Y"; endcase
            16: case(index) 0:label_char="P";1:label_char="H";2:label_char="Y"; endcase
            17: case(index) 0:label_char="E";1:label_char="R";2:label_char="R";3:label_char="O";4:label_char="R"; endcase
            18: case(index) 0:label_char="A";1:label_char="C";2:label_char="K"; endcase
        endcase
    end
endfunction
function label_pixel_at;
    input [10:0] px,x0;
    input [9:0] py,y0;
    input [4:0] id;
    reg [10:0] dx;
    reg [9:0] dy;
    reg [3:0] index;
    reg [2:0] col,row;
    reg [34:0] bits;
    begin
        label_pixel_at=0;
        if(px>=x0 && px<x0+11'd384 && py>=y0 && py<y0+10'd28) begin
            dx=px-x0; dy=py-y0; index=dx[8:5];
            col=dx[4:2]; row=dy[4:2];
            bits=glyph(label_char(id,index));
            if(col<5 && row<7) label_pixel_at=bits[34-row*5-col];
        end
    end
endfunction
function hex_pixel_at;
    input [10:0] px,x0;
    input [9:0] py,y0;
    input [15:0] value;
    input [2:0] digits;
    reg [9:0] dy;
    reg [3:0] nibble;
    reg [7:0] c;
    reg [2:0] col,row;
    reg [34:0] bits;
    begin
        hex_pixel_at=0;
        if(py>=y0 && py<y0+10'd28) begin
            dy=py-y0;
            nibble=0;
            if (px[10:5] == x0[10:5])
                nibble=digits==4 ? value[15:12] :
                       digits==2 ? value[7:4] : value[3:0];
            else if (digits>=2 && px[10:5] == x0[10:5]+6'd1)
                nibble=digits==4 ? value[11:8] : value[3:0];
            else if (digits==4 && px[10:5] == x0[10:5]+6'd2)
                nibble=value[7:4];
            else if (digits==4 && px[10:5] == x0[10:5]+6'd3)
                nibble=value[3:0];
            else nibble=0;
            c=nibble<10 ? 8'h30+{4'd0,nibble} : 8'h41+{4'd0,nibble}-8'd10;
            col=px[4:2]; row=dy[4:2]; bits=glyph(c);
            if(px[10:5]>=x0[10:5] &&
               px[10:5]<x0[10:5]+digits &&
               col<5 && row<7) hex_pixel_at=bits[34-row*5-col];
        end
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        enable_q1<=0;enable_q2<=0;enable_frame<=0;
        link_q1<=0;link_q2<=0;link_frame<=0;
        hb_q1<=0;hb_q2<=0;hb_frame<=0;
        dis_q1<=0;dis_q2<=0;dis_frame<=0;
        diag_q1<=0;diag_q2<=0;diag_frame<=0;
        result_q1<=0;result_q2<=0;result_frame<=0;
        title_pixel<=0;label_pixel<=0;value_pixels<=0;
    end else begin
        enable_q1<=enable_50m;enable_q2<=enable_q1;
        link_q1<=link_50m;link_q2<=link_q1;
        hb_q1<=heartbeat_50m;hb_q2<=hb_q1;
        dis_q1<=display_50m;dis_q2<=dis_q1;
        diag_q1<=diagnostic_50m;diag_q2<=diag_q1;
        result_q1<=result_50m;result_q2<=result_q1;
        if(x==0 && y==0) begin
            enable_frame<=enable_q2;link_frame<=link_q2;
            hb_frame<=hb_q2;dis_frame<=dis_q2;
            diag_frame<=diag_q2;result_frame<=result_q2;
        end
        title_pixel<=label_pixel_at(pre_x,11'd80,pre_y,10'd54,5'd0);
        label_pixel<=
            label_pixel_at(pre_x,11'd80,pre_y,10'd132,5'd1) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd132,5'd2) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd202,5'd3) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd202,5'd4) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd272,5'd5) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd272,5'd6) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd342,5'd7) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd342,5'd8) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd412,5'd9) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd412,5'd10) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd482,5'd11) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd482,5'd12) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd552,5'd13) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd552,5'd14) |
            label_pixel_at(pre_x,11'd80,pre_y,10'd622,5'd15) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd622,5'd16) |
            label_pixel_at(pre_x,11'd920,pre_y,10'd54,5'd17) |
            label_pixel_at(pre_x,11'd640,pre_y,10'd54,5'd18);
        value_pixels[0]<=hex_pixel_at(pre_x,11'd1120,pre_y,10'd54,{8'd0,result_frame},2);
        value_pixels[1]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd132,{15'd0,link_frame},1) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd132,{8'd0,hb_frame[95:88]},2);
        value_pixels[2]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd202,{8'd0,hb_frame[119:112]},2) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd202,{8'd0,hb_frame[111:104]},2);
        value_pixels[3]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd272,{12'd0,hb_frame[11:8]},1) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd272,{12'd0,hb_frame[7:4]},1);
        value_pixels[4]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd342,{8'd0,hb_frame[103:96]},2) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd342,{8'd0,dis_frame[95:88]},2);
        value_pixels[5]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd412,{8'd0,dis_frame[87:80]},2) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd412,{8'd0,dis_frame[79:72]},2);
        value_pixels[6]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd482,{8'd0,dis_frame[71:64]},2) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd482,{8'd0,dis_frame[63:56]},2);
        value_pixels[7]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd552,{8'd0,dis_frame[55:48]},2) |
                         hex_pixel_at(pre_x,11'd1056,pre_y,10'd552,dis_frame[31:16],4);
        value_pixels[8]<=hex_pixel_at(pre_x,11'd480,pre_y,10'd622,dis_frame[15:0],4) |
                         hex_pixel_at(pre_x,11'd1120,pre_y,10'd622,{8'd0,diag_frame[119:112]},2);
    end
end
always @* begin
    rgb=base_rgb;
    if(enable_frame && de) begin
        rgb=24'h122033;
        if(y<10'd100) rgb=24'h263F59;
        if((y>=10'd120 && y<10'd175) ||
           (y>=10'd260 && y<10'd315) ||
           (y>=10'd400 && y<10'd455) ||
           (y>=10'd540 && y<10'd595)) rgb=24'h1C3047;
        if(title_pixel) rgb=24'hFFE0A6;
        if(label_pixel) rgb=24'hB9CDD9;
        if(|value_pixels) rgb=24'h64E3C0;
    end
end
endmodule

`default_nettype wire
