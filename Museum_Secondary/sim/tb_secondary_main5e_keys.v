`timescale 1ns/1ps
module tb_secondary_main5e_keys;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [127:0] hb=128'h01020001000000800000000000000000;
reg [95:0] display=96'h000302030301000000000000;
reg hb_pulse=0, display_pulse=0;
reg ready=1, peer_alive=1;
reg [3:0] switches=0;
reg passed=0;
wire request;
wire [7:0] request_type;
wire [63:0] request_payload;
wire [3:0] debounced_switches;
secondary_main5e_keys dut (
    .clk(clk), .rst(rst), .sw(switches), .key_n(4'hf),
    .heartbeat_pulse(hb_pulse), .heartbeat_data(hb),
    .display_pulse(display_pulse), .display_data(display),
    .control_ready(ready), .peer_alive(peer_alive),
    .control_request(request),
    .control_type(request_type), .control_payload(request_payload),
    .help_switches(debounced_switches)
);
task press;
    input [3:0] keys;
    begin
        force dut.key_press=keys;
        @(negedge clk);
        release dut.key_press;
    end
endtask
task snapshot;
    begin
        @(negedge clk); hb_pulse=1; display_pulse=1;
        @(negedge clk); hb_pulse=0; display_pulse=0;
        @(negedge clk);
    end
endtask
initial begin
    repeat(3) @(negedge clk); rst=0;
    hb_pulse=1; display_pulse=1;
    @(negedge clk); hb_pulse=0; display_pulse=0;
    press(4'b0100);
    if (!request || request_type!=8'h13 || request_payload[63:32]!=32'h02010000)
        $fatal(1,"preset KEY3");
    @(negedge clk);
    force dut.sw_stable=4'b0001;
    press(4'b0010);
    if (!request || request_type!=8'h14 ||
        request_payload[63:32]!=32'h04020303)
        $fatal(1,"brightness +1 absolute");
    @(negedge clk);
    force dut.sw_stable=4'b0010;
    press(4'b0100);
    if (!request || request_payload[63:32]!=32'h03020302)
        $fatal(1,"temperature -1 absolute");
    @(negedge clk);
    force dut.sw_stable=4'b0011;
    display=96'h0003020303010000ff1a0000;
    display_pulse=1;
    @(negedge clk); display_pulse=0;
    press(4'b0001);
    if (!request || request_type!=8'h15 ||
        request_payload!=64'h02000100ff100000)
        $fatal(1,"viewport clamping to -240");
    release dut.sw_stable;
    hb[111:104]=8'hff;
    hb_pulse=1;
    @(negedge clk); hb_pulse=0;
    force dut.sw_stable=4'b1000;
    force dut.key_press=4'b0001;
    #1;
    if (debounced_switches != 4'b1000)
        $fatal(1,"SW4 must only enable help, never the old local carousel");
    @(negedge clk);
    if (!request || request_type != 8'h13)
        $fatal(1,"help page KEY1 must retain main-board preset");
    release dut.key_press;
    hb[111:104]=8'd0;
    hb_pulse=1;
    @(negedge clk); hb_pulse=0;
    press(4'b0001);
    if (!request || request_type!=8'h13)
        $fatal(1,"lecture KEY1 lost its original preset function");
    @(negedge clk);
    force dut.sw_stable=4'b1100;
    @(negedge clk);
    if (request || !debounced_switches[2])
        $fatal(1,"SW3 mute must not issue a mode request");
    press(4'b0001);
    if (!request || request_type!=8'h13)
        $fatal(1,"mute blocked a preset in automatic mode");
    hb[127:120]=2; hb[103:96]=5;
    display[42]=1;
    snapshot();
    repeat(2) @(negedge clk);
    press(4'b1000);
    if (!request || request_type!=8'h13 || request_payload!=64'h0301000000000000)
        $fatal(1,"manual mode must retain preset KEY4");
    @(negedge clk);
    force dut.sw_stable=4'b0101;
    press(4'b0010);
    if (!request || request_type!=8'h14 || request_payload[63:32]!=32'h04020303)
        $fatal(1,"manual mode must retain brightness KEY2");
    @(negedge clk);
    force dut.sw_stable=4'b0110;
    press(4'b0100);
    if (!request || request_type!=8'h14 || request_payload[63:32]!=32'h03020302)
        $fatal(1,"manual mode must retain temperature KEY3");
    @(negedge clk);
    force dut.sw_stable=4'b0111;
    press(4'b0010);
    if (!request || request_type!=8'h15)
        $fatal(1,"manual mode must retain viewport KEY2");
    @(negedge clk);
    hb[103:96]=3;
    snapshot();
    press(4'b0010);
    if (request) $fatal(1,"transition key must be discarded");
    hb[103:96]=5;
    snapshot();
    if (request) $fatal(1,"discarded control key replayed");
    press(4'b0001);
    if (!request || request_type!=8'h15)
        $fatal(1,"manual viewport must recover after transition");
    @(negedge clk);
    force dut.sw_stable=4'b1000;
    @(negedge clk);
    if (request || debounced_switches[2])
        $fatal(1,"unmute must not issue a mode request");
    press(4'b0001);
    if (!request || request_type!=8'h13)
        $fatal(1,"SW3 disagreed with main mode and blocked a preset");
    display[42]=0; hb[127:120]=1; hb[103:96]=0;
    hb[111:104]=8'hff; display[39:32]=8'hff;
    snapshot();
    // After mode-off/recovery, all normal key groups must work again.
    force dut.sw_stable=4'b0001;
    snapshot(); press(4'b0010);
    if (!request || request_type!=8'h14)
        $fatal(1,"normal parameters did not return after manual exit");
    @(negedge clk);
    hb[127:120]=2; hb[79:72]=0; hb[103:96]=2;
    hb[111:104]=1; display[39:32]=1; display[55:48]=2;
    snapshot();
    force dut.sw_stable=4'b0011;
    press(4'b0010);
    if (!request || request_type!=8'h15)
        $fatal(1,"normal viewport did not return after manual exit");
    @(negedge clk);
    hb[127:120]=1; hb[79:72]=0; hb[103:96]=0;
    hb[111:104]=8'hff; display[39:32]=8'hff;
    release dut.sw_stable;
    // Cold boot with the mute switch already asserted.
    rst=1; switches=4'b0100; peer_alive=0; ready=0;
    repeat(3) @(negedge clk); rst=0;
    repeat(1000010) @(negedge clk);
    if (!debounced_switches[2] || request)
        $fatal(1,"initial mute switch sampling");
    peer_alive=1; ready=1;
    press(4'b0100);
    if (request) $fatal(1,"startup must wait for fresh peer status");
    hb[95:88]=1;
    snapshot(); press(4'b0100);
    if (request) $fatal(1,"emergency must block controls");
    hb[95:88]=0; hb[70]=1;
    snapshot(); press(4'b0100);
    if (request) $fatal(1,"recovery must block controls");
    hb[70]=0;
    snapshot(); press(4'b0100);
    if (!request || request_type!=8'h13)
        $fatal(1,"controls did not recover while mute is held");
    passed=1;
    $display("PASS tb_secondary_main5e_keys");
    $finish;
end
initial begin #20000000; $fatal(1,"timeout"); end
endmodule
