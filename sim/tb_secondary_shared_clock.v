`timescale 1ns / 1ps
module tb_secondary_shared_clock;
reg refclk = 0;
reg reset = 1;
initial #200 reset = 0;
always #10 refclk = !refclk;
wire mem_clk, mem_sft, eth_clk, eth_90, locked;
wire old_mem, old_mem_sft, old_eth, old_eth_90;
secondary_media_eth_pll dut (
    .refclk(refclk), .reset(reset), .mem_clk(mem_clk), .mem_clk_sft(mem_sft),
    .eth_clk(eth_clk), .eth_clk_90(eth_90), .locked(locked)
);
sys_pll old_memory (
    .refclk(refclk), .reset(reset), .clk0_out(),
    .clk1_out(old_mem), .clk2_out(old_mem_sft)
);
pll_gen old_network (
    .refclk(refclk), .reset(reset), .extlock(), .clk0_out(),
    .clk1_out(old_eth), .clk2_out(), .clk3_out(), .clk4_out(old_eth_90)
);
real m_prev = 0, e_prev = 0, om_prev = 0, oe_prev = 0;
real mem_phase = 0, old_mem_phase = 0, eth_phase = 0, old_eth_phase = 0;
real mem_period = 0, eth_period = 0;
always @(posedge mem_clk) begin mem_period = $realtime-m_prev; m_prev=$realtime; end
always @(posedge eth_clk) begin eth_period = $realtime-e_prev; e_prev=$realtime; end
always @(posedge old_mem) om_prev=$realtime;
always @(posedge old_eth) oe_prev=$realtime;
always @(posedge mem_sft) mem_phase=$realtime-m_prev;
always @(posedge old_mem_sft) old_mem_phase=$realtime-om_prev;
always @(posedge eth_90) eth_phase=$realtime-e_prev;
always @(posedge old_eth_90) old_eth_phase=$realtime-oe_prev;
reg test_pass = 0;
initial begin
    wait(locked);
    #10000;
    $display("CLOCK periods mem=%0.3f eth=%0.3f; phases mem=%0.3f old=%0.3f eth=%0.3f old=%0.3f", mem_period,eth_period,mem_phase,old_mem_phase,eth_phase,old_eth_phase);
    if (mem_period < 19.99 || mem_period > 20.01) $fatal(1,"memory frequency");
    if (eth_period < 7.99 || eth_period > 8.01) $fatal(1,"Ethernet frequency");
    if (mem_phase-old_mem_phase > 0.02 || old_mem_phase-mem_phase > 0.02) $fatal(1,"memory phase changed");
    if (eth_phase-old_eth_phase > 0.02 || old_eth_phase-eth_phase > 0.02) $fatal(1,"Ethernet phase changed");
    test_pass = 1;
    $display("PASS shared PLL preserves original clock frequencies and relative phases");
    $finish;
end
initial begin #1000000; $fatal(1,"PLL never locked"); end
endmodule
