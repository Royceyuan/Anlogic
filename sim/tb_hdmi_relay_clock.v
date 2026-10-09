`timescale 1ns / 100fs
module tb_hdmi_relay_clock;
reg clk50=0,rst_n=0,source_clk=0,source_enabled=1;
real source_period=13.4680135;
always #10 clk50=!clk50;
always #(source_period/2) source_clk=source_enabled ? !source_clk : 0;
reg phase_step=0,phase_select=0;
wire sclk,pclk,pixel_clk,locked,done,valid;
wire [19:0] edges;
hdmi_relay_clock #(.CLOCKS_PER_MS(500)) dut(.clk_50m(clk50),.rst_n(rst_n),
    .source_clk(source_clk),.phase_step(phase_step),.phase_select(phase_select),
    .sclk(sclk),.pclk(pclk),.pixel_clk(pixel_clk),.pll_locked(locked),
    .phase_done(done),.clock_valid(valid),.measured_edges(edges));
reg [31:0] random_bits=32'h7cab2913;
reg [2:0] data=0;
always #(source_period/10) begin
    random_bits={random_bits[30:0],random_bits[31]^random_bits[21]^random_bits[1]^random_bits[0]};
    data={random_bits[3],random_bits[11],random_bits[23]};
end
wire [3:0] serial_in={source_clk,data};
wire [3:0] serial_out;
wire [15:0] nibbles;
reg phy_rst=1,checking=0;
hdmi_relay_phy phy(.pclk(pclk),.sclk(sclk),.sampler_rst(phy_rst),
    .transmitter_rst(phy_rst),.serial_in(serial_in),.serial_out(serial_out),.nibbles(nibbles));
reg [255:0] in_history [0:3];
reg [63:0] out_history [0:3];
reg [255:0] expected;
integer samples=0,latency=-1,checks=0,lane,offset;
reg same;
always @(sclk) if(checking) begin
    for(lane=0;lane<4;lane=lane+1) in_history[lane]={in_history[lane][254:0],serial_in[lane]};
    #0.02;
    for(lane=0;lane<4;lane=lane+1) out_history[lane]={out_history[lane][62:0],serial_out[lane]};
    samples=samples+1;
    if(samples>100 && latency<0) for(offset=0;offset<64;offset=offset+1) begin
        same=1;
        for(lane=0;lane<4;lane=lane+1) begin
            expected=in_history[lane]>>offset;
            if(expected[31:0]!==out_history[lane][31:0]) same=0;
        end
        if(same && latency<0) latency=offset;
    end
    if(latency>=0) begin
        for(lane=0;lane<4;lane=lane+1) begin
            expected=in_history[lane]>>latency;
            if(expected[31:0]!==out_history[lane][31:0]) $fatal(1,"PLL/DDR lane %d lost serial ordering",lane);
        end
        checks=checks+1;
    end
end
task check_phy;
real t0,t1,t2;
begin
    wait(valid && locked);
    repeat(100) @(posedge pclk);
    @(posedge pclk); t0=$realtime;
    @(posedge pclk); t1=$realtime;
    @(posedge sclk); t0=$realtime;
    @(posedge sclk); t2=$realtime-t0;
    if(t2<source_period/5-0.02 || t2>source_period/5+0.02) $fatal(1,"SCLK frequency");
    @(posedge pclk); t0=$realtime;
    @(posedge pclk); t1=$realtime-t0;
    if(t1<source_period*0.4-0.02 || t1>source_period*0.4+0.02) $fatal(1,"PCLK frequency");
    for(lane=0;lane<4;lane=lane+1) begin in_history[lane]=0;out_history[lane]=0;end
    samples=0;latency=-1;checks=0;
    @(negedge pclk);phy_rst=0;checking=1;
    wait(checks>=2000);
    checking=0;phy_rst=1;
    $display("PASS recovered PLL + DDRx2 RX/DDRx1 TX at pixel period %0.6f ns, common delay %0d UI",source_period,latency);
end endtask
task shift;
input select;
begin
    @(negedge clk50);phase_select=select;phase_step=1;
    repeat(4) @(negedge clk50);
    phase_step=0;
    repeat(24) @(negedge clk50);
end endtask
reg test_pass=0;
initial begin
    #200;rst_n=1;
    check_phy;
    shift(0);shift(1);
    check_phy;
    source_enabled=0;
    #50000;
    if(valid || locked) $fatal(1,"source loss failed to reset receiver");
    source_period=6.73400675;source_enabled=1;
    #50000;
    if(valid) $fatal(1,"1080p clock accepted");
    source_enabled=0;#30000;
    source_period=13.4814815;source_enabled=1;
    check_phy;
    source_enabled=0;#30000;
    source_period=13.333333333;source_enabled=1;
    check_phy;
    source_enabled=0;#30000;
    source_period=13.26259947;source_enabled=1;
    #50000;
    if(valid || locked) $fatal(1,"75.4 MHz outside diagnostic range accepted");
    $display("PASS source loss, unsupported frequency and 59.94 Hz reacquisition");
    $display("PASS 75 MHz main-board source accepted, 75.4 MHz rejected");
    test_pass=1;$finish;
end
initial begin #500000;$fatal(1,"PLL/PHY timeout");end
endmodule
