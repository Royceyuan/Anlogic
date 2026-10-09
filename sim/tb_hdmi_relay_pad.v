`timescale 1ns / 1ps
// Compare the actual mapped IOL modes against the logical PHY, not just RTL.
module tb_hdmi_relay_pad;
reg sclk=0,pclk=0,rst=1;
always #1.333333 sclk=!sclk;
initial begin #0.666667;forever begin pclk=!pclk;#2.666667;end end
reg [31:0] bits=32'hc9a7613e;
reg [3:0] incoming=0;
integer index=0;
initial begin
    #0.1;
    forever begin
        bits={bits[30:0],bits[31]^bits[21]^bits[1]^bits[0]};
        incoming={index%10<5,bits[20]^bits[3],bits[13]^bits[9],bits[7]^bits[31]};
        index=index+1;#1.333333;
    end
end
wire [15:0] words,pad_words;
wire [3:0] outgoing,pad_out;
reg capture_toggle,serial_toggle;
always @(posedge pclk or posedge rst)
    if(rst) capture_toggle<=0;else capture_toggle<=!capture_toggle;
always @(negedge sclk) serial_toggle<=capture_toggle;
hdmi_relay_phy u_logic(.pclk(pclk),.sclk(sclk),.sampler_rst(rst),.transmitter_rst(rst),
    .serial_in(incoming),.nibbles(words),.serial_out(outgoing));
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : g_lane
    EG_PHY_PAD #(.MODE("IN"),.IOTYPE("LVDS33"),.IDDRMODE("DDRX2"),
        .IDDRPIPEMODE("PIPED"),.IN_DFFMODE("NONE"),.IN_REGSET("RESET"),
        .INCEMUX("1"),.INRSTMUX("RST"),.INSCLKMUX("CLK"),.INPCLKMUX("CLK"),.SRMODE("ASYNC")) u_rx(
        .ipad(incoming[lane]),.isclk(sclk),.ipclk(pclk),.rst(rst),.ce(1'b1),
        .osclk(1'b0),.opclk(1'b0),.ts(1'b1),.do(4'b0),.opad(),.bpad(),.di(),
        .diq(pad_words[lane*4+:4]));
    reg [1:0] pair,output_pair;
    always @(negedge sclk)
        pair<=capture_toggle!=serial_toggle ? pad_words[lane*4+:2] : pad_words[lane*4+2+:2];
    always @(posedge sclk) output_pair<=pair;
    EG_PHY_PAD #(.MODE("OUT"),.IOTYPE("LVDS33"),.DRIVE("NA"),.ODDRMODE("DDRX1"),
        .DO_DFFMODE("FF"),.DO_REGSET("RESET"),.OUTCEMUX("1"),.OUTRSTMUX("RST"),
        .OUTSCLKMUX("CLK"),.OUTPCLKMUX("CLK"),.SRMODE("ASYNC"),.TSMUX("0")) u_tx(
        .do({2'b00,output_pair}),.osclk(sclk),.rst(rst),.opad(pad_out[lane]),
        .ipad(1'b0),.ce(1'b1),.isclk(1'b0),.ipclk(1'b0),.opclk(1'b0),.ts(1'b0),
        .bpad(),.di(),.diq());
end endgenerate
integer checks=0;
reg test_pass=0;
initial begin #200;rst=0;end
real last_clock_edge=0,clock_interval;
always @(pad_out[3]) if($time>250) begin
    if(last_clock_edge!=0) begin
        clock_interval=$realtime-last_clock_edge;
        if(clock_interval<6.65 || clock_interval>6.68)
            $fatal(1,"forwarded clock has invalid half-period: %0.3f ns",clock_interval);
    end
    last_clock_edge=$realtime;
end
always @(sclk) if(!rst) begin
    #0.05;
    if($time>250) begin
        if(pad_words!==words) $fatal(1,"mapped RX differs: pad=%h logic=%h",pad_words,words);
        if(pad_out!==outgoing) $fatal(1,"mapped TX differs: pad=%h logic=%h",pad_out,outgoing);
        checks=checks+1;
        if(checks==1000) begin
            $display("PASS mapped DDRx2 RX/DDRx1 TX PAD modes match logical PHY; forwarded clock is 75 MHz/50%% duty");
            test_pass=1;$finish;
        end
    end
end
initial begin #5000;$fatal(1,"mapped PAD timeout");end
endmodule
