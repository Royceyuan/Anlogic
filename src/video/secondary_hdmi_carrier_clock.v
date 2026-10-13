`timescale 1ns/1ps
`default_nettype none
// The carrier follows qualified PC input, never UART play authorization.
// SDRAM/TF/network clocks and resets are not switched by this module.
module secondary_hdmi_carrier_clock #(
    parameter integer SETTLE_CYCLES=50000
)(
    input wire clk_50m,rst_n,native_ready,pc_ready,
    input wire native_pixel_clk,native_serial_clk,pc_pixel_clk,pc_serial_clk,
    output wire pixel_clk,serial_clk,
    output reg pc_clock_selected=0,
    output wire stable
);
reg [1:0] state=0;
reg [1:0] native_ready_ff;
always @(posedge clk_50m or negedge rst_n)
    if(!rst_n) native_ready_ff<=0;else native_ready_ff<={native_ready_ff[0],native_ready};
reg [15:0] cycles=0;
always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin state<=0;cycles<=0;pc_clock_selected<=0;end
    else case(state)
        0: if(cycles==7) begin pc_clock_selected<=pc_ready;cycles<=0;state<=1;end
           else cycles<=cycles+1'b1;
        1: if(pc_ready!=pc_clock_selected) begin state<=0;cycles<=0;end
           else if(!(pc_clock_selected?pc_ready:native_ready_ff[1])) cycles<=0;
           else if(cycles==SETTLE_CYCLES-1) begin state<=2;cycles<=0;end
           else cycles<=cycles+1'b1;
        2: if(pc_ready!=pc_clock_selected) begin state<=0;cycles<=0;end
        default: begin state<=0;cycles<=0;end
    endcase
end
assign stable=rst_n && state==2 && pc_ready==pc_clock_selected &&
    (pc_clock_selected?pc_ready:native_ready_ff[1]);
EG_PHY_CSB #(.HOLD("YES"),.INITOUT("0"),.PRESELECT("CLK0")) u_pixel_mux(
    .clko(pixel_clk),.ce(2'b11),.clki({pc_pixel_clk,native_pixel_clk}),
    .ignr(2'b11),.sel({pc_clock_selected,~pc_clock_selected}));
EG_PHY_CSB #(.HOLD("YES"),.INITOUT("0"),.PRESELECT("CLK0")) u_serial_mux(
    .clko(serial_clk),.ce(2'b11),.clki({pc_serial_clk,native_serial_clk}),
    .ignr(2'b11),.sel({pc_clock_selected,~pc_clock_selected}));
endmodule
`default_nettype wire
