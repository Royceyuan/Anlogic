`timescale 1ns / 100fs
module tb_hdmi_relay_diag;
reg clk50=0;
always #10 clk50=!clk50;
reg [3:0] incoming=0;
reg source_enabled=1,sink_hpd=0;
tri1 sda;
wire hpd;
wire [3:0] outgoing,led;
wire [7:0] seg,sel;
top_secondary_hdmi_relay_diag dut(.clk_50m(clk50),.hdmi_b_clk_p(incoming[3]),
    .hdmi_b_d2_p(incoming[2]),.hdmi_b_d1_p(incoming[1]),.hdmi_b_d0_p(incoming[0]),
    .hdmi_b_scl(1'b1),.hdmi_b_sda(sda),.hdmi_b_hpd(hpd),.hdmi_a_hpd(sink_hpd),
    .hdmi1_clk_p(outgoing[3]),.hdmi1_d2_p(outgoing[2]),
    .hdmi1_d1_p(outgoing[1]),.hdmi1_d0_p(outgoing[0]),
    .led(led),.seg_data(seg),.seg_sel(sel));
// Short frame/window for a runnable end-to-end check; production values remain
// 1650 x 750, 8 good frames, and a 1 ms clock measurement window.
defparam dut.u_clock.CLOCKS_PER_MS=500;
defparam dut.HPD_LOW_CYCLES=5000;
defparam dut.u_monitor.H_TOTAL=32;
defparam dut.u_monitor.V_TOTAL=16;
defparam dut.u_monitor.GOOD_FRAMES=2;
function [9:0] control;
input vs,hs;
begin case({vs,hs})
    0:control=10'h354;1:control=10'h0ab;2:control=10'h154;3:control=10'h2ab;
endcase end endfunction
integer x,y,bit_index;
reg [9:0] a,b,c;
initial forever begin
    for(y=0;y<16;y=y+1) for(x=0;x<32;x=x+1) begin
        a=x<16 ? (10'h012+x+y) : control(y>=12&&y<14,x>=20&&x<24);
        b=x<16 ? (10'h123+x) : 10'h354;
        c=x<16 ? (10'h234+y) : 10'h354;
        for(bit_index=0;bit_index<10;bit_index=bit_index+1) begin
            incoming=source_enabled && hpd ? {bit_index<5,c[bit_index],b[bit_index],a[bit_index]} : 0;
            #1.34680135;
        end
    end
end
task ready;
begin
    wait(dut.format_ff[1] && dut.tx_reset_n);
    repeat(100) @(posedge dut.pclk);
    if(led[3:1]!==3'b111) $fatal(1,"diagnostic ready flags");
end endtask
reg test_pass=0;
initial begin
    wait(dut.rst_n);
    repeat(200) @(posedge clk50);
    if(hpd) $fatal(1,"missing startup HPD low interval");
    wait(hpd);
    wait(dut.format_ff[1]);
    if(dut.tx_reset_n || outgoing!==0) $fatal(1,"output enabled without sink");
    $display("PASS startup HPD interval and source qualification without downstream HPD");
    sink_hpd=1;
    ready;
    force dut.heartbeat=27'h4000000;#10;
    if(dut.diagnostic_value!==16'hbc10) $fatal(1,"B page did not separate source clock activity from idle DDC");
    release dut.heartbeat;
    $display("PASS B-page bus/clock diagnostics preserve a running relay");
    $display("PASS diagnostic top qualifies a live stream before enabling all four output lanes");
    force dut.u_monitor.format_ok=1'b0;
    repeat(4) @(posedge clk50);
    force dut.seek_cycles=24'd9999999;
    @(posedge clk50);#1;release dut.seek_cycles;
    wait(dut.phase_busy);
    release dut.u_monitor.format_ok;
    wait(!dut.phase_busy);
    if(dut.phase_index!=1) $fatal(1,"phase scan did not advance");
    ready;
    $display("PASS bounded phase retune releases reset and requalifies without a stuck wait");
    sink_hpd=0;#1000;
    if(!hpd || dut.tx_reset_n || outgoing!==0) $fatal(1,"sink disconnect did not preserve source and mute relay");
    sink_hpd=1;ready;
    source_enabled=0;#50000;
    if(dut.clock_valid || dut.tx_reset_n || outgoing!==0) $fatal(1,"source loss did not mute relay");
    source_enabled=1;ready;
    $display("PASS sink/source unplug and reconnect reacquire without board reset");
    test_pass=1;$finish;
end
initial begin #4000000;$fatal(1,"diagnostic top timeout");end
endmodule
