`timescale 1ns / 1ps
`default_nettype none

module seg_hex_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [15:0] value,
    output reg  [7:0]  seg_data,
    output reg  [7:0]  seg_sel
);

reg [15:0] scan_cnt;
reg [1:0]  digit_sel;
reg [3:0]  digit_val;

function [7:0] hex_to_seg;
    input [3:0] hex;
    begin
        case (hex)
            4'h0: hex_to_seg = 8'b1100_0000;
            4'h1: hex_to_seg = 8'b1111_1001;
            4'h2: hex_to_seg = 8'b1010_0100;
            4'h3: hex_to_seg = 8'b1011_0000;
            4'h4: hex_to_seg = 8'b1001_1001;
            4'h5: hex_to_seg = 8'b1001_0010;
            4'h6: hex_to_seg = 8'b1000_0010;
            4'h7: hex_to_seg = 8'b1111_1000;
            4'h8: hex_to_seg = 8'b1000_0000;
            4'h9: hex_to_seg = 8'b1001_0000;
            4'hA: hex_to_seg = 8'b1000_1000;
            4'hB: hex_to_seg = 8'b1000_0011;
            4'hC: hex_to_seg = 8'b1100_0110;
            4'hD: hex_to_seg = 8'b1010_0001;
            4'hE: hex_to_seg = 8'b1000_0110;
            4'hF: hex_to_seg = 8'b1000_1110;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scan_cnt <= 16'd0;
    end else begin
        scan_cnt <= scan_cnt + 16'd1;
    end
end

always @(*) begin
    digit_sel = scan_cnt[15:14];
    case (digit_sel)
        2'd0: digit_val = value[3:0];
        2'd1: digit_val = value[7:4];
        2'd2: digit_val = value[11:8];
        default: digit_val = value[15:12];
    endcase

    seg_data = hex_to_seg(digit_val);
    case (digit_sel)
        2'd0: seg_sel = 8'b1111_1110;
        2'd1: seg_sel = 8'b1111_1101;
        2'd2: seg_sel = 8'b1111_1011;
        default: seg_sel = 8'b1111_0111;
    endcase
end

endmodule

`default_nettype wire
