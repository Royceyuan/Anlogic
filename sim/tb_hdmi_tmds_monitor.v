`timescale 1ns / 1ps
module tb_hdmi_tmds_monitor;
reg clk=0,rst_n=0;
always #3 clk=!clk;
reg [11:0] nibbles=0;
wire lanes_locked,format_ok,frame_toggle;
wire [11:0] bit_offsets;
hdmi_tmds_monitor #(.H_TOTAL(32),.V_TOTAL(16),.GOOD_FRAMES(2)) dut(
    .clk(clk),.rst_n(rst_n),.nibbles(nibbles),.lanes_locked(lanes_locked),
    .format_ok(format_ok),.frame_toggle(frame_toggle),.bit_offsets(bit_offsets)
);
reg [11:0] next_nibble=0;
integer nibble_bits=0;
reg unequal_offsets=0;
reg [2:0] previous_bits=0,older_bits=0;
task emit_bit;
input [2:0] bits;
begin
    next_nibble[nibble_bits]=bits[0];
    next_nibble[nibble_bits+4]=unequal_offsets ? previous_bits[1] : bits[1];
    next_nibble[nibble_bits+8]=unequal_offsets ? older_bits[2] : bits[2];
    older_bits=previous_bits;previous_bits=bits;
    nibble_bits=nibble_bits+1;
    if(nibble_bits==4) begin @(negedge clk); nibbles=next_nibble; nibble_bits=0; next_nibble=0; end
end endtask
task emit_word;
input [9:0] a,b,c;
integer i;
begin for(i=0;i<10;i=i+1) emit_bit({c[i],b[i],a[i]}); end
endtask
function [9:0] ctrl;
input vs,hs;
begin case({vs,hs})
    0:ctrl=10'h354; 1:ctrl=10'h0ab; 2:ctrl=10'h154; 3:ctrl=10'h2ab;
endcase end endfunction
function [9:0] tc;
input vs,hs;
begin case({vs,hs})
    0:tc=10'h28e; 1:tc=10'h271; 2:tc=10'h163; 3:tc=10'h2c3;
endcase end endfunction
task emit_frame;
input integer width;
integer x,y;
reg hs,vs;
begin for(y=0;y<16;y=y+1) for(x=0;x<width;x=x+1) begin
    hs=x>=20&&x<24; vs=y>=12&&y<14;
    if(x<16) emit_word(10'h012,10'h123,10'h234);
    else if(x>=24&&x<=25) emit_word(tc(vs,hs),10'h133,10'h133);
    else if(x>=26&&x<=29) emit_word(tc(vs,hs),10'h29c,10'h263);
    else emit_word(ctrl(vs,hs),10'h354,10'h354);
end end endtask
integer i;
reg test_pass=0;
reg format_ever_seen=0;
always @(posedge clk) if(format_ok) format_ever_seen=1;
initial begin
    #50; rst_n=1;
    for(i=0;i<7;i=i+1) emit_bit(3'b101);
    for(i=0;i<8;i=i+1) emit_frame(32);
    if(!format_ok) $fatal(1,"format qualification lost during live valid video");
    if(!lanes_locked || !format_ever_seen) $fatal(1,"failed to lock: lanes=%b offsets=%h format=%b frame=%d line_bad=%b seen_vs=%b good=%d last=%b line=%d",dut.lane_lock,bit_offsets,format_ok,dut.frame_symbols,dut.line_bad,dut.seen_vs,dut.good_count,dut.last_vs,dut.line_symbols);
    $display("PASS 4-to-10 symbol alignment, all three lanes and HDMI data-island sync");
    for(i=0;i<3;i=i+1) emit_frame(36);
    repeat(8) @(posedge clk);
    if(format_ok) $fatal(1,"wrong timing accepted");
    $display("PASS invalid frame timing rejected");
    rst_n=0;repeat(4) @(posedge clk);rst_n=1;
    nibble_bits=0;next_nibble=0;unequal_offsets=1;
    for(i=0;i<8;i=i+1) emit_frame(32);
    if(lanes_locked || format_ok) $fatal(1,"raw relay accepted unequal lane bit offsets");
    $display("PASS unequal lane offsets rejected until sampling phase is retrained");
    test_pass=1; $finish;
end
initial begin #1000000; $fatal(1,"monitor timeout"); end
endmodule
