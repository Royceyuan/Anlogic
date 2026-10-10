`timescale 1ns / 1ps
`default_nettype none
// Clock switching happens only while the one output IOL bank is reset.
// Local media and Ethernet clocks/reset are never switched or reset here.
module secondary_hdmi_source_switch #(
    parameter integer SETTLE_CYCLES=50000
)(
    input wire clk_50m,rst_n,local_ready,external_ready,
    input wire local_blank,external_blank,
    input wire local_sclk,external_sclk,
    input wire [7:0] local_pairs,external_pairs,
    output reg external_selected=0,
    output wire [3:0] serial_out,
    output wire output_muted
);
reg [1:0] local_ready_ff,local_blank_ff,external_blank_ff;
always @(posedge clk_50m or negedge rst_n)
    if(!rst_n) begin local_ready_ff<=0;local_blank_ff<=0;external_blank_ff<=0;end
    else begin
        local_ready_ff<={local_ready_ff[0],local_ready};
        local_blank_ff<={local_blank_ff[0],local_blank};
        external_blank_ff<={external_blank_ff[0],external_blank};
    end
wire desired=external_ready;
wire selected_ready=external_selected ? external_ready : local_ready_ff[1];
wire selected_blank=external_selected ? external_blank_ff[1] : local_blank_ff[1];
localparam MUTE=0,SETTLE=1,RUN=2;
reg [1:0] state=MUTE;
reg [15:0] cycles=0;
reg mute=1;
always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin state<=MUTE;cycles<=0;mute<=1;external_selected<=0;end
    else case(state)
        MUTE: begin
            mute<=1;
            if(cycles==7) begin external_selected<=desired;cycles<=0;state<=SETTLE;end
            else cycles<=cycles+1'b1;
        end
        SETTLE: begin
            if(desired!=external_selected) begin state<=MUTE;cycles<=0;end
            else if(!selected_ready) cycles<=0;
            else if(cycles==SETTLE_CYCLES-1) begin
                if(selected_blank) begin mute<=0;state<=RUN;cycles<=0;end
            end
            else cycles<=cycles+1'b1;
        end
        RUN: if(desired!=external_selected || !selected_ready) begin mute<=1;state<=MUTE;cycles<=0;end
        default: begin mute<=1;state<=MUTE;cycles<=0;end
    endcase
end
wire output_sclk;
// Vendor CSB forces a switch even if the lost input clock stopped high.
// Any shortened edge during that switch is contained by the mute interval.
// Same CSB configuration as EG_LOGIC_BUFGMUX, instantiated directly so its
// clock output pin has a stable name during both elaboration and routing.
EG_PHY_CSB #(.HOLD("YES"),.INITOUT("0"),.PRESELECT("CLK0")) u_clock_mux(
    .clko(output_sclk),.ce(2'b11),.clki({external_sclk,local_sclk}),
    .ignr(2'b11),.sel({external_selected,~external_selected}));
reg [3:0] reset_release=4'hf;
always @(posedge output_sclk or posedge mute)
    if(mute) reset_release<=4'hf;
    else reset_release<={reset_release[2:0],1'b0};
assign output_muted=reset_release[3];
reg [7:0] output_pairs;
always @(posedge output_sclk) output_pairs<=external_selected ? external_pairs : local_pairs;
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : g_lane
    EG_LOGIC_ODDR u_output(.q(serial_out[lane]),.clk(output_sclk),.rst(output_muted),
        .d0(output_pairs[lane*2]),.d1(output_pairs[lane*2+1]));
end endgenerate
endmodule
`default_nettype wire
