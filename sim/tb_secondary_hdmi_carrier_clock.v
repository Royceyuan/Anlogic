`timescale 1ns/1ps
module tb_secondary_hdmi_carrier_clock;
reg clk50=0,np=0,ns=0,pp=0,ps=0,rst_n=0,pc_ready=0,pc_running=1;
always #10 clk50=!clk50;
always #6.666667 np=!np;
always #1.333333 ns=!ns;
always #6.734006 if(pc_running) pp=!pp;
always #1.346801 if(pc_running) ps=!ps;
wire pclk,sclk,selected,stable;
secondary_hdmi_carrier_clock #(.SETTLE_CYCLES(64)) dut(.clk_50m(clk50),.rst_n(rst_n),
    .native_ready(1'b1),.pc_ready(pc_ready),.native_pixel_clk(np),.native_serial_clk(ns),
    .pc_pixel_clk(pp),.pc_serial_clk(ps),.pixel_clk(pclk),.serial_clk(sclk),
    .pc_clock_selected(selected),.stable(stable));
reg request_pc=0;
reg [39:0] words;
always @(posedge pclk) words<={10'b0000011111,request_pc?30'h1334cce4:30'h15555555};
wire [7:0] pairs;
wire [3:0] out;
wire [3:0] reference;
secondary_hdmi_symbol_pairs u_tx(.pixel_clk(pclk),.serial_clk(sclk),.symbols(words),.pairs(pairs));
genvar g;
generate for(g=0;g<4;g=g+1) begin:lane
    Serial_N_1_lvds_dat #(.N(10),.FAMILY("EG4")) u_ref(.DP_I(words[g*10+:10]),.PCLK(pclk),.SCLK(sclk),.DSP_O(reference[g]));
    EG_LOGIC_ODDR u_out(.clk(sclk),.rst(!rst_n),.d0(pairs[2*g]),.d1(pairs[2*g+1]),.q(out[g]));
end endgenerate
real previous_pixel=0,previous_serial=0,previous_clock=0;
integer pixel_edges=0,serial_edges=0,clock_edges=0;
reg measuring=0,test_pass=0;
reg [63:0] history[0:3],actual[0:3];
reg [63:0] shifted;
integer samples=0,latency=-1,offset,lane_index,serial_checks=0;
reg matched;
initial for(lane_index=0;lane_index<4;lane_index=lane_index+1) begin history[lane_index]=0;actual[lane_index]=0;end
always @(sclk) if(measuring) begin
    #0.3;
    for(lane_index=0;lane_index<4;lane_index=lane_index+1) begin
        history[lane_index]={history[lane_index][62:0],reference[lane_index]};
        actual[lane_index]={actual[lane_index][62:0],out[lane_index]};
    end
    samples=samples+1;
    if(samples>80 && latency<0) for(offset=0;offset<16;offset=offset+1) begin
        matched=1;
        for(lane_index=0;lane_index<4;lane_index=lane_index+1) begin
            shifted=history[lane_index]>>offset;
            if(shifted[31:0]!==actual[lane_index][31:0]) matched=0;
        end
        if(matched&&latency<0) latency=offset;
    end
    if(latency>=0) begin
        for(lane_index=0;lane_index<4;lane_index=lane_index+1) begin
            shifted=history[lane_index]>>latency;
            if(shifted[31:0]!==actual[lane_index][31:0]) $fatal(1,"common carrier serialized data differs from vendor");
        end
        serial_checks=serial_checks+1;
    end
end
always @(posedge pclk) if(measuring) begin
    if(pixel_edges && ($realtime-previous_pixel<13.4 || $realtime-previous_pixel>13.55)) $fatal(1,"pixel clock interrupted during authorization");
    previous_pixel=$realtime;pixel_edges=pixel_edges+1;
end
always @(posedge sclk) if(measuring) begin
    if(serial_edges && ($realtime-previous_serial<2.68 || $realtime-previous_serial>2.71)) $fatal(1,"serial clock interrupted during authorization");
    previous_serial=$realtime;serial_edges=serial_edges+1;
end
always @(out[3]) if(measuring) begin
    if(clock_edges && ($realtime-previous_clock<6.7 || $realtime-previous_clock>6.8)) $fatal(1,"TMDS clock lane interrupted during authorization");
    previous_clock=$realtime;clock_edges=clock_edges+1;
end
initial begin
    #100;rst_n=1;wait(stable);
    if(selected) $fatal(1,"boot clock is not native");
    $display("PASS native carrier is usable without PC (no renderer-reset deadlock)");
    pc_ready=1;wait(stable&&selected);#1000;measuring=1;
    repeat(40) begin #179;request_pc=!request_pc;end
    measuring=0;
    if(pixel_edges<100 || serial_edges<500 || clock_edges<100 || serial_checks<1000 || !stable || !selected) $fatal(1,"carrier measurements insufficient");
    $display("PASS 40 authorization changes: pixel/serial/TMDS-clock continuity, clock gap ZERO in this functional model");
    $display("PASS changing word sources on recovered carrier match vendor serialization on all four actual IOL lanes");
    @(posedge pp);@(posedge ps);#0.01;pc_running=0;pc_ready=0;
    wait(stable&&!selected);
    $display("PASS dead PC clocks held HIGH return to native without waiting for a dead edge");
    pc_running=1;pc_ready=1;wait(stable&&selected);
    @(negedge pp);@(negedge ps);#0.01;pc_running=0;pc_ready=0;
    wait(stable&&!selected);
    $display("PASS dead PC clocks held LOW return to native, fresh source can reconnect");
    test_pass=1;$finish;
end
initial begin #50000;$fatal(1,"carrier timeout");end
endmodule
