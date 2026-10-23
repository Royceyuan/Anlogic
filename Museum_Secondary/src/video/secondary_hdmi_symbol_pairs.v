`timescale 1ns / 1ps
`default_nettype none
// One shared four-lane serializer. Choose complete words in the pixel domain
// before this module; neither source selection nor authorization resets it.
// Same toggle/shift/pair pipeline as the board-tested local transmitter.
module secondary_hdmi_symbol_pairs (
    input wire pixel_clk,serial_clk,
    input wire [39:0] symbols,
    output wire [7:0] pairs
);
reg pixel_toggle=0;
always @(posedge pixel_clk) pixel_toggle<=!pixel_toggle;
reg toggle_q=0,toggle_qq=0,load=0,load_d=0,load_dd=0;
always @(posedge serial_clk) begin
    toggle_q<=pixel_toggle;toggle_qq<=toggle_q;
    load<=toggle_q^toggle_qq;load_d<=load;load_dd<=load_d;
end
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : g_lane
    reg [9:0] shift;
    reg [1:0] pair,pair_d;
    always @(posedge serial_clk) begin
        if(load_dd) shift<=symbols[lane*10+:10];
        else shift<={2'b0,shift[9:2]};
        pair<=shift[1:0];pair_d<=pair;
    end
    assign pairs[lane*2+:2]=pair_d;
end endgenerate
endmodule
`default_nettype wire
