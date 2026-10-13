`timescale 1ns / 1ps
`default_nettype none
// Original vendor RGB encoder; original serializer toggle/shift pipeline,
// shared across the four lanes and stopped just before the output IOL.
module secondary_hdmi_local_pairs #(
    parameter integer HDMI_PACKETS=0
)(
    input wire pixel_clk,serial_clk,rst_n,hs,vs,de,
    input wire [23:0] rgb,
    output wire [7:0] pairs,
    output wire encoder_ready,
    output wire encoder_blank,
    output wire [39:0] symbols
);
function is_control;
input [9:0] code;
begin is_control=code==10'h354||code==10'h0ab||code==10'h154||code==10'h2ab;end
endfunction
generate if(HDMI_PACKETS) begin : g_hdmi
    reg blank=0;
    // The packet core regenerates raster timing: input DE is not its output
    // blank. Release the output only in an actual three-lane control period.
    always @(posedge pixel_clk or negedge rst_n)
        if(!rst_n) blank<=0;
        else blank<=is_control(symbols[9:0])&&is_control(symbols[19:10])&&is_control(symbols[29:20]);
    assign encoder_blank=blank;
    secondary_hdmi_packet_symbols u_packets(.clk(pixel_clk),.rst_n(rst_n),.vs(vs),.de(de),.rgb(rgb),
        .symbols(symbols),.locked(encoder_ready));
end else begin : g_dvi
TMDSEncoder u_blue(.D_I(rgb[7:0]),.C0_I(hs),.C1_I(vs),.DE_I(de),.CLK_I(pixel_clk),.RST_I(rst_n),.D_O(symbols[9:0]));
TMDSEncoder u_green(.D_I(rgb[15:8]),.C0_I(1'b0),.C1_I(1'b0),.DE_I(de),.CLK_I(pixel_clk),.RST_I(rst_n),.D_O(symbols[19:10]));
TMDSEncoder u_red(.D_I(rgb[23:16]),.C0_I(1'b0),.C1_I(1'b0),.DE_I(de),.CLK_I(pixel_clk),.RST_I(rst_n),.D_O(symbols[29:20]));
assign symbols[39:30]=10'b0000011111;
assign encoder_ready=rst_n;
assign encoder_blank=!de;
end endgenerate
secondary_hdmi_symbol_pairs u_serializer(.pixel_clk(pixel_clk),.serial_clk(serial_clk),
    .symbols(symbols),.pairs(pairs));
endmodule
`default_nettype wire
