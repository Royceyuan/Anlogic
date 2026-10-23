`timescale 1ns/1ps
`default_nettype none
// A bundled snapshot remains stable until acknowledgement. Newer states coalesce
// while a transfer is in flight; individual bits are never independently sampled.
module secondary_offline_request_cdc #(
    parameter integer WIDTH=41,
    parameter [WIDTH-1:0] INITIAL={32'd0,8'hff,1'b1}
)(
    input wire source_clk,source_rst_n,
    input wire [WIDTH-1:0] source_data,
    input wire target_clk,target_rst_n,
    output reg [WIDTH-1:0] target_data
);
reg [WIDTH-1:0] held;
reg request,acknowledge;
reg [1:0] ack_sync,request_sync;
always @(posedge source_clk or negedge source_rst_n)
    if(!source_rst_n)begin held<=INITIAL;request<=0;ack_sync<=0;end
    else begin
        ack_sync<={ack_sync[0],acknowledge};
        if(ack_sync[1]==request&&source_data!=held)begin
            held<=source_data;request<=!request;
        end
    end
always @(posedge target_clk or negedge target_rst_n)
    if(!target_rst_n)begin request_sync<=0;acknowledge<=0;target_data<=INITIAL;end
    else begin
        request_sync<={request_sync[0],request};
        if(request_sync[1]!=acknowledge)begin
            target_data<=held;acknowledge<=request_sync[1];
        end
    end
endmodule
`default_nettype wire
