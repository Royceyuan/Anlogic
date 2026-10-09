`timescale 1ns / 1ps
`default_nettype none

// Sideband only: the relay never reconstructs RGB or strips data islands.
// Each input nibble is chronological, with the earliest sampled bit in bit0.
module hdmi_tmds_monitor #(
    parameter integer H_TOTAL=1650, V_TOTAL=750, GOOD_FRAMES=8
) (
    input wire clk, rst_n,
    input wire [11:0] nibbles,
    output reg lanes_locked,
    output reg format_ok,
    output reg frame_toggle,
    output wire [11:0] bit_offsets
);
reg [3:0] bits_used;
reg [13:0] reservoir [0:2];
wire [13:0] joined [0:2];
reg [9:0] raw_word [0:2], previous_word [0:2];
reg raw_valid;
reg [3:0] offsets [0:2], hits [0:2];
reg [2:0] lane_lock;
reg [9:0] aligned [0:2];
reg [3:0] aligned_offset [0:2];
reg aligned_valid;
reg [19:0] shifted_word [0:2];
reg [3:0] shifted_offset [0:2];
reg shifted_valid;
wire [9:0] candidate [0:2];
genvar g;
generate for(g=0;g<3;g=g+1) begin : g_lane
    assign joined[g]=reservoir[g] | ({10'd0,nibbles[g*4+:4]} << bits_used);
    assign candidate[g]=shifted_word[g] >> {shifted_offset[g][3:2],2'b00};
end endgenerate
// Raw relay has no per-lane symbol deskew. Reject a phase which captures
// adjacent bits on different lanes, rather than forwarding corrupt pixels.
always @(posedge clk or negedge rst_n)
    if(!rst_n) lanes_locked<=0;
    else lanes_locked<=(&lane_lock) && offsets[0]==offsets[1] && offsets[0]==offsets[2];
assign bit_offsets={offsets[2],offsets[1],offsets[0]};
function [2:0] control;
input [9:0] word;
begin case(word)
    10'h354: control=3'b100;
    10'h0ab: control=3'b101;
    10'h154: control=3'b110;
    10'h2ab: control=3'b111;
    default: control=0;
endcase end endfunction
function [4:0] terc4;
input [9:0] word;
begin case(word)
    10'h29c:terc4=5'h10; 10'h263:terc4=5'h11;
    10'h2e4:terc4=5'h12; 10'h2e2:terc4=5'h13;
    10'h171:terc4=5'h14; 10'h11e:terc4=5'h15;
    10'h18e:terc4=5'h16; 10'h13c:terc4=5'h17;
    10'h2cc:terc4=5'h18; 10'h139:terc4=5'h19;
    10'h19c:terc4=5'h1a; 10'h2c6:terc4=5'h1b;
    10'h28e:terc4=5'h1c; 10'h271:terc4=5'h1d;
    10'h163:terc4=5'h1e; 10'h2c3:terc4=5'h1f;
    default:terc4=0;
endcase end endfunction
reg [2:0] ctrl0,ctrl1,ctrl2;
reg [4:0] island_sync;
reg island_guard,decoded_valid;
// Keep ten-bit code decoding out of the state/mux path at 185.625 MHz.
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ctrl0<=0;ctrl1<=0;ctrl2<=0;island_sync<=0;island_guard<=0;decoded_valid<=0;
    end else begin
        decoded_valid<=aligned_valid && lanes_locked;
        if(aligned_valid && lanes_locked) begin
            ctrl0<=control(aligned[0]);ctrl1<=control(aligned[1]);ctrl2<=control(aligned[2]);
            island_sync<=terc4(aligned[0]);
            island_guard<=aligned[1]==10'h133 && aligned[2]==10'h133;
        end
    end
end
reg in_island;
reg [3:0] island_preamble;
// Guard/TERC4 words can also be legal RGB symbols. HDMI 5.2.1.1 requires
// eight control characters (CTL0:3=1010) before an island guard band.
wire island_begin=island_guard && island_preamble==8 && island_sync[4];
reg symbol_tick,sync_valid;
reg [1:0] sync_value;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin in_island<=0;island_preamble<=0;symbol_tick<=0;sync_valid<=0;sync_value<=0;end
    else begin
        symbol_tick<=decoded_valid;
        if(decoded_valid) begin
            if(ctrl0[2] && ctrl1==3'b101 && ctrl2==3'b101) begin
                if(island_preamble<8) island_preamble<=island_preamble+1'b1;
            end else island_preamble<=0;
            if(island_begin) in_island<=1;
            else if(ctrl0[2] && ctrl1[2] && ctrl2[2]) in_island<=0;
            sync_valid<=ctrl0[2] || ((in_island || island_begin) && island_sync[4]);
            sync_value<=ctrl0[2] ? ctrl0[1:0] : island_sync[1:0];
        end
    end
end
reg last_hs,last_vs,seen_hs,seen_vs,line_bad;
reg [12:0] line_symbols;
reg [21:0] frame_symbols;
reg [3:0] good_count;
reg frame_in_range,line_in_range,line_timeout;
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin frame_in_range<=0;line_in_range<=0;line_timeout<=0;end
    else begin
        frame_in_range<=frame_symbols>=H_TOTAL*V_TOTAL-17 && frame_symbols<=H_TOTAL*V_TOTAL+15;
        line_in_range<=line_symbols>=H_TOTAL-5 && line_symbols<=H_TOTAL+3;
        line_timeout<=line_symbols>H_TOTAL+32;
    end
wire hs_rise=sync_valid && !last_hs && sync_value[0];
wire vs_rise=sync_valid && !last_vs && sync_value[1];
integer i;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        bits_used<=0; raw_valid<=0; aligned_valid<=0; shifted_valid<=0; lane_lock<=0;
        for(i=0;i<3;i=i+1) begin
            reservoir[i]<=0; raw_word[i]<=0; previous_word[i]<=0;
            offsets[i]<=0; hits[i]<=0; aligned[i]<=0; aligned_offset[i]<=0;
            shifted_word[i]<=0;shifted_offset[i]<=0;
        end
    end else begin
        raw_valid<=bits_used>=6;
        if(bits_used>=6) bits_used<=bits_used-6;
        else bits_used<=bits_used+4;
        for(i=0;i<3;i=i+1) begin
            if(bits_used>=6) begin raw_word[i]<=joined[i][9:0]; reservoir[i]<=joined[i]>>10; end
            else reservoir[i]<=joined[i];
        end
        shifted_valid<=raw_valid;
        aligned_valid<=shifted_valid;
        if(raw_valid) for(i=0;i<3;i=i+1) begin
            previous_word[i]<=raw_word[i];
            shifted_word[i]<={raw_word[i],previous_word[i]} >> offsets[i][1:0];
            shifted_offset[i]<=offsets[i];
        end
        if(shifted_valid) for(i=0;i<3;i=i+1) begin
            aligned[i]<=candidate[i];aligned_offset[i]<=shifted_offset[i];
        end
        if(aligned_valid) for(i=0;i<3;i=i+1) begin
            if(!lane_lock[i] && aligned_offset[i]==offsets[i]) begin
                if(control(aligned[i])!=0) begin
                    // HDMI guarantees a four-character minimum control period.
                    if(hits[i]==3) lane_lock[i]<=1;
                    else hits[i]<=hits[i]+1'b1;
                end else begin
                    hits[i]<=0; offsets[i]<=offsets[i]==9 ? 0 : offsets[i]+1'b1;
                end
            end
        end
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        format_ok<=0; frame_toggle<=0; last_hs<=0; last_vs<=0;
        seen_hs<=0; seen_vs<=0; line_bad<=0;
        line_symbols<=0; frame_symbols<=0; good_count<=0;
    end else if(symbol_tick) begin
        if(line_symbols!=8191) line_symbols<=line_symbols+1'b1;
        if(frame_symbols!=22'h3fffff) frame_symbols<=frame_symbols+1'b1;
        if(sync_valid) begin last_hs<=sync_value[0]; last_vs<=sync_value[1]; end
        if(hs_rise) begin
            if(seen_hs && !line_in_range) begin
                line_bad<=1; format_ok<=0;
            end
            line_symbols<=0; seen_hs<=1;
        end
        if(vs_rise) begin
            frame_toggle<=!frame_toggle; frame_symbols<=0; seen_vs<=1; line_bad<=0;
            // Registered comparator has one PCLK latency, smaller than the
            // stated +/-16-symbol tolerance. It removes a 22-bit timing chain.
            if(seen_vs && !line_bad && frame_in_range) begin
                if(good_count<GOOD_FRAMES) good_count<=good_count+1'b1;
                if(good_count>=GOOD_FRAMES-1) format_ok<=1;
            end else begin good_count<=0; format_ok<=0; end
        end
        if(line_timeout) format_ok<=0;
    end
end
endmodule
`default_nettype wire
