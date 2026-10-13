`timescale 1ns/1fs
// Reproduce the vendor PLL's floating-point period comparison near 2^26 ns.
// Keep vendor code unchanged; use an exactly representable source period.
module tb_secondary_hdmi_pll_model;
reg clk=0,start=0,rst_n=0,binary_clk=0,decimal_clk=0;
initial begin wait(start);forever #10 clk=!clk;end
initial begin wait(start);forever #6.671875 binary_clk=!binary_clk;end
initial begin wait(start);forever #6.665 decimal_clk=!decimal_clk;end
wire binary_lock,decimal_lock;
hdmi_relay_clock #(.CLOCKS_PER_MS(500)) binary_source(.clk_50m(clk),.rst_n(rst_n),.source_clk(binary_clk),
    .phase_step(1'b0),.phase_select(1'b0),.pll_locked(binary_lock));
hdmi_relay_clock #(.CLOCKS_PER_MS(500)) decimal_source(.clk_50m(clk),.rst_n(rst_n),.source_clk(decimal_clk),
    .phase_step(1'b0),.phase_select(1'b0),.pll_locked(decimal_lock));
integer binary_changes=0,decimal_changes=0;
reg test_pass=0;
always @(binary_source.u_rx_pll.tmp_time_value)
    if($realtime>67108864 && binary_source.u_rx_pll.tmp_time_value!=0) binary_changes=binary_changes+1;
always @(decimal_source.u_rx_pll.tmp_time_value)
    if($realtime>67108864 && decimal_source.u_rx_pll.tmp_time_value!=0) decimal_changes=decimal_changes+1;
initial begin
    #67000000;start=1;#100;rst_n=1;#400000;
    if(!binary_lock || binary_changes || decimal_changes==0)
        $fatal(1,"unexpected PLL precision result binary=%0d decimal=%0d lock=%b",binary_changes,decimal_changes,binary_lock);
    $display("PASS vendor PLL precision reproduction: 13.33ns false changes=%0d; exact 13.34375ns changes=%0d, locked=%b",decimal_changes,binary_changes,binary_lock);
    test_pass=1;$finish;
end
endmodule
