`timescale 1ns / 1ps
module tb_hdmi_relay_phy;
reg sclk=0,pclk=0,rst=1;
always #1.5 sclk=!sclk;
initial begin #0.75; forever begin pclk=!pclk; #3; end end
reg [31:0] random_bits=32'hc9a7613e;
reg [3:0] serial_in=0;
integer source_index=0;
initial begin
    #0.25;
    forever begin
        random_bits={random_bits[30:0],random_bits[31]^random_bits[21]^random_bits[1]^random_bits[0]};
        serial_in={source_index%10<5,random_bits[20]^random_bits[3],random_bits[13]^random_bits[9],random_bits[7]^random_bits[31]};
        source_index=source_index+1;
        #1.5;
    end
end
wire [15:0] nibbles;
wire [3:0] serial_out;
hdmi_relay_phy dut(.pclk(pclk),.sclk(sclk),.sampler_rst(rst),.transmitter_rst(rst),
    .serial_in(serial_in),.serial_out(serial_out),.nibbles(nibbles));
reg [255:0] input_history [0:3];
reg [63:0] output_history [0:3];
reg [255:0] expected;
integer sample_count=0,latency=-1,lane,offset,checks=0;
reg all_equal,test_pass=0;
initial begin
    for(lane=0;lane<4;lane=lane+1) begin input_history[lane]=0; output_history[lane]=0; end
    #200; rst=0;
end
always @(sclk) if(!rst) begin
    for(lane=0;lane<4;lane=lane+1) input_history[lane]={input_history[lane][254:0],serial_in[lane]};
    #0.05;
    for(lane=0;lane<4;lane=lane+1) output_history[lane]={output_history[lane][62:0],serial_out[lane]};
    sample_count=sample_count+1;
    if(sample_count>100 && latency<0) begin
        for(offset=0;offset<64;offset=offset+1) begin
            all_equal=1;
            for(lane=0;lane<4;lane=lane+1) begin
                expected=input_history[lane]>>offset;
                if(expected[31:0]!==output_history[lane][31:0]) all_equal=0;
            end
            if(all_equal && latency<0) latency=offset;
        end
    end
    if(latency>=0) begin
        for(lane=0;lane<4;lane=lane+1) begin
            expected=input_history[lane]>>latency;
            if(expected[31:0]!==output_history[lane][31:0]) $fatal(1,"lane %d not bit-exact at fixed delay %d",lane,latency);
        end
        checks=checks+1;
    end
    if(checks==1000) begin
        $display("PASS DDRx2 RX/single-DDR TX: all four serial lanes bit-exact, common latency=%d UI",latency);
        test_pass=1; $finish;
    end
end
initial begin #20000; $fatal(1,"PHY no fixed matching delay"); end
endmodule
