`timescale 1ns/1ps
`default_nettype none
// Both sources now use the same PC raster/clock. Keep the HDMI carrier and
// non-audio information packets continuous while only changing RGB content.
module secondary_hdmi_common_symbols #(
    parameter integer LOCAL_DELAY=28
)(
    input wire clk,rst_n,request_pc,pc_ready,
    input wire [29:0] pc_symbols,local_symbols,
    input wire pc_hs,pc_vs,pc_de,packet_data,keep_packet,pcm_packet,guard_band,
    input wire [4:0] packet_index,
    input wire [31:0] silent_flags,
    output reg [39:0] symbols,
    output wire external_selected,
    output wire aligned
);
function [2:0] control;
input [9:0] code;
begin case(code)
    10'h354:control=4;10'h0ab:control=5;10'h154:control=6;10'h2ab:control=7;
    default:control=0;
endcase end endfunction
function [3:0] un_terc;
input [9:0] code;
begin case(code)
    10'h29c:un_terc=0;10'h263:un_terc=1;10'h2e4:un_terc=2;10'h2e2:un_terc=3;
    10'h171:un_terc=4;10'h11e:un_terc=5;10'h18e:un_terc=6;10'h13c:un_terc=7;
    10'h2cc:un_terc=8;10'h139:un_terc=9;10'h19c:un_terc=10;10'h2c6:un_terc=11;
    10'h28e:un_terc=12;10'h271:un_terc=13;10'h163:un_terc=14;10'h2c3:un_terc=15;
    default:un_terc=0;
endcase end endfunction
function [9:0] terc;
input [3:0] n;
begin case(n)
    0:terc=10'h29c;1:terc=10'h263;2:terc=10'h2e4;3:terc=10'h2e2;
    4:terc=10'h171;5:terc=10'h11e;6:terc=10'h18e;7:terc=10'h13c;
    8:terc=10'h2cc;9:terc=10'h139;10:terc=10'h19c;11:terc=10'h2c6;
    12:terc=10'h28e;13:terc=10'h271;14:terc=10'h163;15:terc=10'h2c3;
endcase end endfunction
function [7:0] bch;
input [7:0] flags;
integer j;
reg [7:0] c;
begin
    c=0;
    for(j=0;j<8;j=j+1) c=(c>>1)^((c[0]^flags[j])?8'h83:8'd0);
    bch=c;
end endfunction
// A fixed-delay ring preserves the same 28 pixel clocks with BRAM instead
// of more than 2000 shift registers; leave Slice room for the real PHY.
reg [73:0] delay_mem[0:31] /* fehdl force_ram=1, ram_style="bram" */;
reg [73:0] delayed;
reg [4:0] write_address;
reg [5:0] filled;
wire [4:0] read_address=write_address-(LOCAL_DELAY-1);
reg [1:0] request_ff,ready_ff;
always @(posedge clk) begin
    delay_mem[write_address]<={silent_flags,guard_band,pcm_packet,keep_packet,packet_data,packet_index,pc_de,pc_vs,pc_hs,pc_symbols};
    delayed<=delay_mem[read_address];
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        request_ff<=0;ready_ff<=0;write_address<=0;filled<=0;
    end else begin
        request_ff<={request_ff[0],request_pc};ready_ff<={ready_ff[0],pc_ready};
        write_address<=write_address+1'b1;
        if(filled<LOCAL_DELAY) filled<=filled+1'b1;
    end
end
wire [29:0] w=filled>=LOCAL_DELAY?delayed[29:0]:{10'h354,10'h354,10'h354};
wire [11:0] t=filled>=LOCAL_DELAY?delayed[41:30]:12'd0;
wire [31:0] f=filled>=LOCAL_DELAY?delayed[73:42]:32'd0;
wire [2:0] lc=control(local_symbols[9:0]);
wire local_control=lc[2]&&control(local_symbols[19:10])!=0&&control(local_symbols[29:20])!=0;
wire pc_control=control(w[9:0])!=0&&control(w[19:10])!=0&&control(w[29:20])!=0;
reg last_pc_vs,last_local_vs;
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin last_pc_vs<=0;last_local_vs<=0;end
    else begin last_pc_vs<=t[1];if(local_control) last_local_vs<=lc[1];end
wire allow_pc;
secondary_hdmi_frame_handoff u_handoff(
    .clk(clk),.rst_n(rst_n),.request_pc(request_ff[1]),.local_ready(1'b1),.pc_ready(ready_ff[1]),
    .local_frame_tick(local_control&&lc[1]&&!last_local_vs),.pc_frame_tick(t[1]&&!last_pc_vs),
    .local_vblank(lc[1]),.pc_vblank(t[1]),.local_control(local_control),.pc_control(pc_control),
    .phase_aligned(aligned),.external_selected(external_selected),.pc_payload_allowed(allow_pc));
reg [29:0] chosen;
reg [3:0] blue,green,red;
reg [63:0] zero_sp;
integer sp;
always @* begin
    chosen=w;blue=un_terc(w[9:0]);green=0;red=0;zero_sp=0;
    if(t[2] && !allow_pc) chosen=local_symbols;
    else if(t[8] && !allow_pc && !t[9]) begin
        if(t[10]) begin
            // Silence layout-0 LPCM without changing ACR/raster or headers.
            // If a lease is revoked midway through a packet, that one packet
            // may fail BCH; the following complete packets carry valid zeros.
            for(sp=0;sp<4;sp=sp+1) begin
                zero_sp={bch(f[sp*8+:8]),f[sp*8+:8],48'd0};
                green[sp]=zero_sp[{t[7:3],1'b0}];
                red[sp]=zero_sp[{t[7:3],1'b1}];
            end
        end else blue[2]=0; // unknown audio/auxiliary packet -> valid Null
        chosen={terc(red),terc(green),terc(blue)};
    end else if(!allow_pc && !t[8] && !pc_control && !t[11]) begin
        // Fail closed on unclassified words: never expose a PC RGB word
        // merely because a malformed/DVI stream omitted HDMI preambles.
        case(t[1:0])
            0:chosen={10'h354,10'h354,10'h354};
            1:chosen={10'h354,10'h354,10'h0ab};
            2:chosen={10'h354,10'h354,10'h154};
            3:chosen={10'h354,10'h354,10'h2ab};
        endcase
    end
end
always @(posedge clk or negedge rst_n)
    if(!rst_n) symbols<={10'b0000011111,10'h354,10'h354,10'h354};
    else symbols<={10'b0000011111,chosen};
endmodule
`default_nettype wire
