`timescale 1ns/1ps
module tb_secondary_main5e_keys;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [127:0] hb=128'h01020001000000800000000000000000;
reg [95:0] display=96'h000302030301000000000000;
reg hb_pulse=0, display_pulse=0;
reg ready=1, peer_alive=1, supported=1;
wire request;
wire [7:0] request_type;
wire [63:0] request_payload;
wire manual_mode, manual_next;
secondary_main5e_keys dut (
    .clk(clk), .rst(rst), .sw(4'd0), .key_n(4'hf),
    .heartbeat_pulse(hb_pulse), .heartbeat_data(hb),
    .display_pulse(display_pulse), .display_data(display),
    .control_ready(ready), .peer_alive(peer_alive), .manual_supported(supported),
    .control_request(request),
    .control_type(request_type), .control_payload(request_payload),
    .manual_mode(manual_mode), .manual_next(manual_next)
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
    if (!manual_mode || !manual_next) $fatal(1,"manual KEY1 pulse");
    @(negedge clk);
    if (request) $fatal(1,"manual KEY1 sent a main-board preset");
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
    if (!request || request_type!=8'h17 || request_payload!=64'h0100000000000000)
        $fatal(1,"SW3 enter mode");
    ready=0;
    press(4'b0001);
    if (manual_next || request) $fatal(1,"SW3 KEY1 must not step carousel or queue an image");
    ready=1;
    repeat(3) @(negedge clk);
    if (request) $fatal(1,"mode mismatch must not flood requests");
    // BUSY permits a new attempt only after fresh main telemetry.
    snapshot();
    if (!request || request_type!=8'h17) $fatal(1,"mode BUSY did not retry on fresh heartbeat");
    ready=0;
    hb[127:120]=2; hb[103:96]=5;
    display[42]=1;
    snapshot();
    ready=1;
    repeat(2) @(negedge clk);
    press(4'b1000);
    if (!request || request_type!=8'h18 || request_payload!=64'h0203000000000000)
        $fatal(1,"KEY4 detail3 must use actual artifact 2");
    @(negedge clk);
    press(4'b0010);
    if (!request || request_type!=8'h18 || request_payload!=64'h0201000000000000)
        $fatal(1,"KEY2 detail1 overrides the normal key group");
    @(negedge clk);
    press(4'b0100);
    if (!request || request_type!=8'h18 || request_payload!=64'h0202000000000000)
        $fatal(1,"KEY3 detail2 overrides the normal key group");
    @(negedge clk);
    hb[103:96]=3;
    snapshot();
    press(4'b0010);
    if (request) $fatal(1,"transition key must be discarded");
    hb[103:96]=5;
    snapshot();
    if (request) $fatal(1,"discarded image key replayed");
    press(4'b0001);
    if (!request || request_type!=8'h18 || request_payload!=64'h0200000000000000)
        $fatal(1,"KEY1 full image");
    @(negedge clk);
    force dut.sw_stable=4'b1000;
    @(negedge clk);
    if (!request || request_type!=8'h17 || request_payload!=0)
        $fatal(1,"SW3 exit mode");
    ready=0;
    display[42]=0; hb[127:120]=1; hb[103:96]=0;
    hb[111:104]=8'hff; display[39:32]=8'hff;
    snapshot();
    ready=1;
    repeat(3) @(negedge clk);
    if (request) $fatal(1,"normal mode must not send repeated exit commands");
    // MAIN KEY4 clearing actual mode must reconcile a still-high SW3.
    force dut.sw_stable=4'b0100;
    snapshot();
    if (!request || request_type!=8'h17) $fatal(1,"recovery did not re-arm desired mode");
    ready=0;
    peer_alive=0;
    repeat(2) @(negedge clk);
    peer_alive=1; ready=1; supported=0;
    snapshot();
    press(4'b0100);
    if (request) $fatal(1,"old peer must not receive unsupported manual commands");
    supported=1;
    hb[95:88]=1;
    snapshot();
    if (request) $fatal(1,"emergency must block mode re-arm");
    hb[95:88]=0;
    snapshot();
    if (!request || request_type!=8'h17) $fatal(1,"valid state must re-arm after emergency");
    repeat(11) snapshot();
    if (dut.mode_attempts!=10 || request) $fatal(1,"BUSY retries must be bounded");
    hb[70]=1;
    snapshot();
    if (request || dut.mode_attempts!=0) $fatal(1,"KEY4 recovery must reset exhausted mode retries");
    hb[70]=0;
    snapshot();
    if (!request || request_type!=8'h17) $fatal(1,"held SW3 must re-arm after KEY4 recovery");
    release dut.sw_stable;
    $display("PASS tb_secondary_main5e_keys");
    $finish;
end
initial begin #10000; $fatal(1,"timeout"); end
endmodule
