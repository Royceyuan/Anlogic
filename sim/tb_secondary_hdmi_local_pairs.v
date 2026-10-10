`timescale 1ns / 1ps
module tb_secondary_hdmi_local_pairs;
reg clk50=0,pclk=0,sclk=0;
always #10 clk50=!clk50;
always #6.666667 pclk=!pclk;
always #1.333333 sclk=!sclk;
reg [23:0] rgb=24'h13579b;
reg [7:0] pixel=0;
always @(posedge pclk) begin pixel<=pixel+1'b1;rgb<={rgb[22:0],rgb[23]^rgb[18]^rgb[5]^rgb[0]};end
wire [7:0] pairs;
secondary_hdmi_local_pairs u_local(.pixel_clk(pclk),.serial_clk(sclk),.rst_n(1'b1),
    .hs(pixel[6]),.vs(pixel[7]),.de(pixel[4]),.rgb(rgb),.pairs(pairs));
wire [3:0] original,out;
genvar g;
generate for(g=0;g<4;g=g+1) begin : g_reference
    Serial_N_1_lvds_dat #(.N(10),.FAMILY("EG4")) u_original(
        .DP_I(u_local.symbols[g*10+:10]),.PCLK(pclk),.SCLK(sclk),.DSP_O(original[g]));
end endgenerate
wire muted;
secondary_hdmi_source_switch #(.SETTLE_CYCLES(64)) u_output(
    .clk_50m(clk50),.rst_n(1'b1),.local_ready(1'b1),.external_ready(1'b0),
    .local_blank(1'b1),.external_blank(1'b0),
    .local_sclk(sclk),.external_sclk(1'b0),.local_pairs(pairs),.external_pairs(8'b0),
    .external_selected(),.serial_out(out),.output_muted(muted));
reg [63:0] history[0:3],actual[0:3];
reg [63:0] shifted;
integer samples=0,latency=-1,offset,lane,checks=0;
reg matched,test_pass=0;
always @(sclk) if($time>3000 && !muted) begin
    #0.3;
    if((^original)===1'bx || (^out)===1'bx) $fatal(1,"unknown local/reference output cannot prove equivalence");
    for(lane=0;lane<4;lane=lane+1) begin
        history[lane]={history[lane][62:0],original[lane]};
        actual[lane]={actual[lane][62:0],out[lane]};
    end
    samples=samples+1;
    if(samples>80 && latency<0) for(offset=0;offset<16;offset=offset+1) begin
        matched=1;
        for(lane=0;lane<4;lane=lane+1) begin shifted=history[lane]>>offset;if(shifted[31:0]!==actual[lane][31:0]) matched=0;end
        if(matched && latency<0) latency=offset;
    end
    if(latency>=0) begin
        for(lane=0;lane<4;lane=lane+1) begin shifted=history[lane]>>latency;if(shifted[31:0]!==actual[lane][31:0]) $fatal(1,"local lane %d differs from vendor serializer",lane);end
        checks=checks+1;
        if(checks==2000) begin
            $display("PASS local common-pair transmitter matches vendor serializer on four lanes, extra delay %d UI",latency);
            test_pass=1;$finish;
        end
    end
end
initial begin for(lane=0;lane<4;lane=lane+1) begin history[lane]=0;actual[lane]=0;end end
initial begin #20000;$fatal(1,"local transmitter comparison timeout muted=%b latency=%d",muted,latency);end
endmodule
