`timescale 1ns / 100fs
module tb_secondary_hdmi_museum;
reg clk=0,scl=1,master_low=0,source_enabled=0;
reg uart_rxd=1;
always #10 clk=!clk;
reg [3:0] incoming=0;
tri1 sda;
assign sda=master_low ? 1'b0 : 1'bz;
wire hpd;
wire [3:0] outgoing,led;
wire [7:0] seg,sel;
top_secondary_hdmi_museum dut(.clk_50m(clk),.hdmi_a_clk_p(incoming[3]),
    .uart_rxd(uart_rxd),.uart_txd(),
    .hdmi_a_d0_p(incoming[0]),.hdmi_a_d1_p(incoming[1]),.hdmi_a_d2_p(incoming[2]),
    .hdmi_a_scl(scl),.hdmi_a_sda(sda),.hdmi_a_hpd(hpd),.hdmi_b_hpd(1'b0),
    .hdmi_b_clk_p(outgoing[3]),.hdmi_b_d0_p(outgoing[0]),
    .hdmi_b_d1_p(outgoing[1]),.hdmi_b_d2_p(outgoing[2]),
    .led(led),.seg_data(seg),.seg_sel(sel));
defparam dut.u_relay.u_clock.CLOCKS_PER_MS=500;
defparam dut.u_switch.SETTLE_CYCLES=64;
defparam dut.u_pc_video.BAUD_DIV=8;
defparam dut.u_relay.u_monitor.H_TOTAL=192;
defparam dut.u_relay.u_monitor.V_TOTAL=16;
defparam dut.u_relay.u_monitor.GOOD_FRAMES=2;
defparam dut.u_relay.g_official_edid.u_slave.u2_iic.myedid_new_ram.inst.INIT_FILE="../vendor/official_hdmi_loop_edid/edid_1280720_with_audio.mif";
function [9:0] control;
input vs,hs;
begin case({vs,hs})
    0:control=10'h354;1:control=10'h0ab;2:control=10'h154;3:control=10'h2ab;
endcase end endfunction
function [7:0] crc8;
input [7:0] c,b;
reg [7:0] w;
integer n;
begin w=c^b;for(n=0;n<8;n=n+1) w=w[7]?(w<<1)^8'h07:w<<1;crc8=w;end
endfunction
task uart_byte;
input [7:0] b;
integer n;
begin
    @(negedge clk);uart_rxd=0;repeat(8) @(negedge clk);
    for(n=0;n<8;n=n+1) begin uart_rxd=b[n];repeat(8) @(negedge clk);end
    uart_rxd=1;repeat(16) @(negedge clk);
end endtask
task uart_command;
input [7:0] command,seq;
begin
    uart_byte(8'ha5);uart_byte(8'h5a);uart_byte(command);uart_byte(seq);
    uart_byte(crc8(crc8(crc8(crc8(0,8'ha5),8'h5a),command),seq));
end endtask
function [9:0] terc;
input [3:0] nibble;
begin case(nibble)
    0:terc=10'h29c;1:terc=10'h263;2:terc=10'h2e4;3:terc=10'h2e2;
    4:terc=10'h171;5:terc=10'h11e;6:terc=10'h18e;7:terc=10'h13c;
    8:terc=10'h2cc;9:terc=10'h139;10:terc=10'h19c;11:terc=10'h2c6;
    12:terc=10'h28e;13:terc=10'h271;14:terc=10'h163;15:terc=10'h2c3;
endcase end endfunction
integer x,y,bit_index;
reg [9:0] a,b,c;
reg hs,vs;
initial forever begin
    wait(source_enabled&&hpd);
    for(y=0;y<16;y=y+1) for(x=0;x<192;x=x+1) begin
        hs=x>=112&&x<144;vs=y>=12&&y<14;
        a=control(vs,hs);b=10'h354;c=10'h354;
        // Balanced legal RGB words which resemble island guards/TERC4.
        if(x<96) begin a=x<32 ? 10'h28e : x<64 ? 10'h271 : 10'h2c3;b=10'h133;c=10'h133;end
        else if(x>=104&&x<112) begin b=10'h0ab;c=10'h0ab;end
        else if(x==112||x==113||x==146||x==147) begin
            a=terc({2'b11,vs,hs});b=10'h133;c=10'h133;
        end else if(x>=114&&x<146) begin
            // 32-character island-style payload, not a valid LPCM/BCH packet.
            a=terc({1'b1,x[0],vs,hs});b=terc(y[3:0]);c=terc(x[3:0]);
        end else if(x>=182&&x<190) b=10'h0ab;
        else if(x>=190) begin a=10'h2cc;b=10'h133;c=10'h2cc;end
        for(bit_index=0;bit_index<10;bit_index=bit_index+1) begin
            incoming=source_enabled ? {bit_index<5,c[bit_index],b[bit_index],a[bit_index]} : 0;
            #1.34680135;
        end
    end
end
task start_i2c;
begin scl=0;master_low=0;#1000;scl=1;#1000;master_low=1;#1000;scl=0;end endtask
task send_byte;
input [7:0] value;
integer i;
begin
    for(i=7;i>=0;i=i-1) begin scl=0;master_low=!value[i];#1000;scl=1;#1000;end
    scl=0;master_low=0;#1000;scl=1;#500;
    if(sda!==0) $fatal(1,"official EDID ACK for %h",value);
    #500;scl=0;#1000;
end endtask
task read_byte;
output [7:0] value;
input ack;
integer i;
begin
    master_low=0;
    for(i=7;i>=0;i=i-1) begin scl=0;#1000;scl=1;#500;value[i]=sda;#500;end
    scl=0;master_low=ack;#1000;scl=1;#1000;scl=0;#1000;master_low=0;
end endtask
reg checking=0;
reg [255:0] in_history [0:3];
reg [63:0] out_history [0:3];
reg [255:0] expected;
integer samples=0,delay=-1,checks=0,lane,offset;
reg equal;
always @(dut.u_relay.sclk) if(checking) begin
    for(lane=0;lane<4;lane=lane+1) in_history[lane]={in_history[lane][254:0],incoming[lane]};
    #0.3;
    for(lane=0;lane<4;lane=lane+1) out_history[lane]={out_history[lane][62:0],outgoing[lane]};
    samples=samples+1;
    if(samples>100 && delay<0) for(offset=0;offset<64;offset=offset+1) begin
        equal=1;
        for(lane=0;lane<4;lane=lane+1) begin
            expected=in_history[lane]>>offset;
            if(expected[31:0]!==out_history[lane][31:0]) equal=0;
        end
        if(equal && delay<0) delay=offset;
    end
    if(delay>=0) begin
        for(lane=0;lane<4;lane=lane+1) begin
            expected=in_history[lane]>>delay;
            if(expected[31:0]!==out_history[lane][31:0]) $fatal(1,"A-to-B lane %d changed bits",lane);
        end
        checks=checks+1;
    end
end
integer i,sum0=0,sum1=0;
reg [7:0] data;
reg test_pass=0;
initial begin
    wait(dut.u_relay.rst_n);repeat(200) @(posedge clk);
    if(hpd) $fatal(1,"official startup HPD low missing");
    // Skip only the long official 2^25-clock delay after checking its low state.
    force dut.u_relay.g_official_edid.u_slave.hpd_reset_cnt=26'd33554432;
    repeat(2) @(posedge clk);#1;
    release dut.u_relay.g_official_edid.u_slave.hpd_reset_cnt;
    if(!hpd || dut.u_relay.clock_valid) $fatal(1,"EDID handshake wrongly requires video clock");
    $display("PASS official HPD asserts independently of HDMI source clock");
    start_i2c;send_byte(8'ha0);send_byte(0);start_i2c;send_byte(8'ha1);
    for(i=0;i<256;i=i+1) begin
        read_byte(data,i!=255);
        if(i==0 && data!=0) $fatal(1,"official EDID header");
        if(i>0 && i<7 && data!=8'hff) $fatal(1,"official EDID header ff");
        if(i==54 && data!=1) $fatal(1,"official preferred pixel clock low byte");
        if(i==55 && data!=8'h1d) $fatal(1,"official preferred pixel clock high byte");
        if(i==144 && data!=8'h09) $fatal(1,"official EDID 2-channel LPCM descriptor");
        if((i==145 || i==146) && data!=8'h04) $fatal(1,"official EDID 48kHz/24-bit audio capability");
        if(i<128) sum0=sum0+data;else sum1=sum1+data;
    end
    scl=0;master_low=1;#1000;scl=1;#1000;master_low=0;#1000;
    if(sum0%256 || sum1%256) $fatal(1,"official EDID checksum");
    if(!dut.u_relay.edid_read_seen) $fatal(1,"passive observer missed read address");
    $display("PASS official ROM both blocks read/checksum while passive monitor never drives SDA");
    source_enabled=1;wait(dut.u_relay.format_ff[1]);
    repeat(100) @(posedge clk);
    if(dut.external_selected||dut.pc_play_enabled) $fatal(1,"valid desktop auto-selected without UART START");
    $display("PASS valid connected PC stays local until UART authorizes video");
    uart_command(1,1);wait(dut.external_selected&&!dut.output_muted);
    repeat(100) @(posedge dut.u_relay.pclk);
    if(!dut.external_selected || dut.output_muted || dut.u_relay.sink_ff[1]) $fatal(1,"unreliable sink HPD gated qualified output");
    $display("PASS A-input/B-output candidate qualifies source without sink-HPD gate");
    // Start latency search on changing packet words, not a flat color band
    // whose ten-bit repetition can falsely match multiple pipeline delays.
    wait(x==118 && bit_index==0);
    for(lane=0;lane<4;lane=lane+1) begin in_history[lane]=0;out_history[lane]=0;end
    checking=1;wait(checks>=2000);checking=0;
    $display("PASS all four lanes including clock and island-style payload keep common delay %d UI",delay);
    source_enabled=0;#50000;
    if(dut.u_relay.clock_valid || dut.external_selected || dut.output_muted) $fatal(1,"source loss did not restore local output");
    if(dut.u_terminal.background_ticks<100000) $fatal(1,"background application stopped during passthrough");
    $display("PASS source loss restores local output while background application keeps running");
    source_enabled=1;wait(dut.u_relay.format_ff[1]);repeat(100) @(posedge clk);
    if(dut.external_selected||dut.pc_play_enabled) $fatal(1,"reconnect reused old authorization");
    uart_command(1,2);wait(dut.external_selected&&!dut.output_muted);
    $display("PASS source reconnect requires fresh UART authorization while EDID remains available");
    uart_command(2,3);wait(!dut.external_selected&&!dut.output_muted);
    if(!dut.external_ready||dut.pc_play_enabled) $fatal(1,"STOP reset HDMI receiver or retained authorization");
    $display("PASS UART STOP restores local without unplugging HDMI or resetting receiver");
    test_pass=1;$finish;
end
initial begin #10000000;$fatal(1,"candidate timeout clock=%b PLL=%b locks=%b offsets=%h format=%b lines=%d frames=%d",dut.u_relay.clock_valid,dut.u_relay.pll_locked,dut.u_relay.u_monitor.lane_lock,dut.u_relay.bit_offsets,dut.u_relay.format_ok,dut.u_relay.u_monitor.line_symbols,dut.u_relay.u_monitor.frame_symbols);end
endmodule
