`timescale 1ns/1ps
`default_nettype none
// Delay only a validated automatic-entry request. Media timing is untouched.
module museum_voice_handoff #(parameter integer CLOCK_HZ=50_000_000,TIMEOUT_MS=500)(
    input wire clk,rst_n,request,need_handoff,abort,muted_pulse,
    output reg pending,confirm
);
localparam integer LIMIT=CLOCK_HZ/1000*TIMEOUT_MS;
localparam integer BITS=$clog2(LIMIT+1);
reg [BITS-1:0] elapsed;
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin pending<=0;confirm<=0;elapsed<=0;end
    else begin
        confirm<=0;
        if(abort)begin pending<=0;elapsed<=0;end
        else if(pending)begin
            if(muted_pulse||elapsed==LIMIT-1)begin pending<=0;confirm<=1;elapsed<=0;end
            else elapsed<=elapsed+1'b1;
        end else if(request)begin
            elapsed<=0;
            if(need_handoff)pending<=1;else confirm<=1;
        end
    end
end
endmodule
`default_nettype wire
