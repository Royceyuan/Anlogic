`timescale 1ns / 1ps
module tb_secondary_hdmi_source_switch;
reg clk=0,local_clk=0,ext_clk=0,rst_n=0,local_ready=0,ext_ready=0,ext_running=1;
reg local_blank=0,ext_blank=0;
always #10 clk=!clk;
always #1.333333 local_clk=!local_clk;
always begin #1.346801; if(ext_running) ext_clk=!ext_clk;end
reg [7:0] lp=0,ep=0;
always @(posedge local_clk) lp<=lp+8'h17;
always @(posedge ext_clk) ep<=ep+8'h23;
wire selected,muted;
wire [3:0] tx;
secondary_hdmi_source_switch #(.SETTLE_CYCLES(64)) dut(
    .clk_50m(clk),.rst_n(rst_n),.local_ready(local_ready),.external_ready(ext_ready),
    .local_blank(local_blank),.external_blank(ext_blank),
    .local_sclk(local_clk),.external_sclk(ext_clk),.local_pairs(lp),.external_pairs(ep),
    .external_selected(selected),.output_muted(muted),.serial_out(tx));
reg [7:0] expect_pair;
reg checking=0;
integer checks=0,lane;
always @(posedge dut.output_sclk) begin
    expect_pair=dut.output_pairs;
    if(checking && !muted) begin
        #0.3;
        for(lane=0;lane<4;lane=lane+1) if(tx[lane]!==expect_pair[lane*2]) $fatal(1,"rising DDR lane %d mismatch tx=%b expected=%h input=%h muted=%b state=%d",lane,tx,expect_pair,dut.output_pairs,muted,dut.state);
        @(negedge dut.output_sclk);#0.3;
        for(lane=0;lane<4;lane=lane+1) if(tx[lane]!==expect_pair[lane*2+1]) $fatal(1,"falling DDR lane mismatch");
        checks=checks+1;
    end
end
always @(selected) if(rst_n && !muted) $fatal(1,"source switched without output reset");
task verify;
input target;
integer before;
begin
    wait(selected==target && !muted);
    repeat(8) @(posedge dut.output_sclk);
    before=checks;checking=1;wait(checks>=before+100);checking=0;
end endtask
reg test_pass=0;
initial begin
    #200;rst_n=1;
    #2000;if(!muted || tx!==0) $fatal(1,"unready local enabled");
    local_ready=1;#2000;if(!muted) $fatal(1,"released during local active pixels");
    local_blank=1;verify(0);$display("PASS local-only output keeps all four lanes paired");
    ext_ready=1;#2000;if(!muted) $fatal(1,"released during external data period");
    ext_blank=1;verify(1);$display("PASS valid external source takes priority after muted clock switch");
    $display("PASS output release waits for target blank/control indication");
    @(posedge ext_clk);#0.1;ext_running=0;ext_ready=0;
    verify(0);$display("PASS external clock stopped HIGH falls back without waiting for a dead edge");
    ext_running=1;ext_ready=1;verify(1);
    @(negedge ext_clk);#0.1;ext_running=0;ext_ready=0;
    verify(0);$display("PASS external clock stopped LOW and reconnect recover without local reset");
    ext_running=1;ext_ready=1;verify(1);
    ext_ready=0;#100;ext_ready=1;verify(1);
    $display("PASS validity change during switch settle restarts safely");
    test_pass=1;$finish;
end
initial begin #100000;$fatal(1,"source switch timeout selected=%b muted=%b",selected,muted);end
endmodule
