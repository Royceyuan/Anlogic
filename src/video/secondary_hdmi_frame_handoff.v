`timescale 1ns / 1ps
`default_nettype none
// All inputs must already be in the common output pixel-clock domain.
// Frame ticks mark vertical-blank entry at the SAME raster coordinate, not
// independently decoded VS edges with different pipeline delays.
// ponytail: handoff guard only, not genlock or a packet-safe blank generator.
// The owner must align the native renderer and generate valid silent/black
// symbols when pc_payload_allowed falls; never substitute reset/zero lanes.
module secondary_hdmi_frame_handoff (
    input wire clk,rst_n,request_pc,local_ready,pc_ready,
    input wire local_frame_tick,pc_frame_tick,local_vblank,pc_vblank,
    input wire local_control,pc_control,
    output reg phase_aligned,
    output reg external_selected,
    output wire pc_payload_allowed
);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin phase_aligned<=0;external_selected<=0;end
    else begin
        if(!local_ready || !pc_ready || (local_frame_tick^pc_frame_tick)) phase_aligned<=0;
        else if(local_frame_tick && pc_frame_tick) phase_aligned<=1;
        // A request can wait while the native picture remains visible.
        // Only ordinary control in aligned vertical blank admits PC content.
        if(local_vblank && local_control && local_ready) begin
            if(!request_pc || !pc_ready || !phase_aligned) external_selected<=0;
            else if(pc_vblank && pc_control) external_selected<=1;
        end
    end
end
// Safety revocation is immediate; frame bookkeeping cannot extend a lease.
// This is an inhibit signal, NOT a finished HDMI/audio muting implementation.
assign pc_payload_allowed=rst_n && request_pc && local_ready && pc_ready &&
    phase_aligned && external_selected;
endmodule
`default_nettype wire
