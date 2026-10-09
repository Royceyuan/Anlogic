`timescale 1ns / 1ps
module tb_hdmi_handshake_diag;
reg clk=0,key1_n=1;
always #10 clk=!clk;
reg hpd_link=1,scl_link=1,sda_link=1,glitch_low=0;
tri1 a_scl,a_sda,b_scl,b_sda;
tranif1 u_scl(a_scl,b_scl,scl_link);
tranif1 u_sda(a_sda,b_sda,sda_link);
assign b_scl=glitch_low ? 1'b0 : 1'bz;
wire b_hpd;
wire a_hpd=hpd_link ? b_hpd : 1'b0;
wire [3:0] led;
wire [7:0] seg_data,seg_sel;
top_secondary_hdmi_handshake_diag #(.PHASE_CYCLES(200),.SETTLE_CYCLES(20)) dut(
    .clk_50m(clk),.key1_n(key1_n),.hdmi_a_hpd(a_hpd),.hdmi_b_hpd(b_hpd),
    .hdmi_a_scl(a_scl),.hdmi_a_sda(a_sda),.hdmi_b_scl(b_scl),.hdmi_b_sda(b_sda),
    .led(led),.seg_data(seg_data),.seg_sel(seg_sel));
defparam dut.u_keys.DEBOUNCE_BITS=3;
task restart;
begin
    @(negedge clk);key1_n=0;
    repeat(16) @(negedge clk);
    key1_n=1;repeat(16) @(negedge clk);
    if(dut.done) $fatal(1,"KEY1 did not restart the test");
end endtask
task result;
input [7:0] expected;
begin
    wait(dut.done);#1;
    if(dut.value!=={8'hf0,expected})
        $fatal(1,"handshake mask expected %h got %h",expected,dut.value);
end endtask
reg test_pass=0;
initial begin
    result(8'hff);
    if(led[3:1]!==3'b111) $fatal(1,"complete PASS LEDs");
    $display("PASS ideal external loop checks HPD, SCL and both SDA directions");
    hpd_link=0;scl_link=0;sda_link=0;restart;result(8'h15);
    $display("PASS missing cable does not falsely report PASS; KEY1 restarts");
    scl_link=1;sda_link=1;restart;result(8'h7d);
    $display("PASS HPD path failure isolated");
    hpd_link=1;scl_link=0;restart;result(8'hf7);
    $display("PASS SCL path failure isolated");
    scl_link=1;sda_link=0;restart;result(8'h9f);
    $display("PASS SDA directional path failure isolated");
    sda_link=1;restart;
    wait(dut.phase==2 && dut.phase_cycles==40);
    @(negedge clk);glitch_low=1;
    repeat(4) @(negedge clk);glitch_low=0;
    result(8'hfb);
    $display("PASS transient failure after settle stays latched, not masked by final level");
    restart;result(8'hff);
    $display("PASS recovery after transient failure and repeated run");
    test_pass=1;$finish;
end
initial begin #2500000;$fatal(1,"handshake probe timeout");end
endmodule
