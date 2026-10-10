`timescale 1ns / 1ps
`default_nettype none
// Original vendor RGB encoder; original serializer toggle/shift pipeline,
// shared across the four lanes and stopped just before the output IOL.
module secondary_hdmi_local_pairs(
    input wire pixel_clk,serial_clk,rst_n,hs,vs,de,
    input wire [23:0] rgb,
    output wire [7:0] pairs
);
wire [39:0] symbols;
TMDSEncoder u_blue(.D_I(rgb[7:0]),.C0_I(hs),.C1_I(vs),.DE_I(de),.CLK_I(pixel_clk),.RST_I(rst_n),.D_O(symbols[9:0]));
TMDSEncoder u_green(.D_I(rgb[15:8]),.C0_I(1'b0),.C1_I(1'b0),.DE_I(de),.CLK_I(pixel_clk),.RST_I(rst_n),.D_O(symbols[19:10]));
TMDSEncoder u_red(.D_I(rgb[23:16]),.C0_I(1'b0),.C1_I(1'b0),.DE_I(de),.CLK_I(pixel_clk),.RST_I(rst_n),.D_O(symbols[29:20]));
assign symbols[39:30]=10'b0000011111;
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
