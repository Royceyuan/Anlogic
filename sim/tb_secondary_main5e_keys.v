`timescale 1ns/1ps
module tb_secondary_main5e_keys;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [127:0] hb=128'h01020001000000800000000000000000;
reg [95:0] display=96'h000302030301000000000000;
reg hb_pulse=0, display_pulse=0;
wire request;
wire [7:0] request_type;
wire [63:0] request_payload;
secondary_main5e_keys dut (
    .clk(clk), .rst(rst), .sw(4'd0), .key_n(4'hf),
    .heartbeat_pulse(hb_pulse), .heartbeat_data(hb),
    .display_pulse(display_pulse), .display_data(display),
    .control_ready(1'b1), .control_request(request),
    .control_type(request_type), .control_payload(request_payload),
    .engineering_page()
);
task press;
    input [3:0] keys;
    begin
        force dut.key_press=keys;
        @(negedge clk);
        release dut.key_press;
    end
endtask
initial begin
    repeat(3) @(negedge clk); rst=0;
    hb_pulse=1; display_pulse=1;
    @(negedge clk); hb_pulse=0; display_pulse=0;
    press(4'b0100);
    if (!request || request_type!=8'h13 || request_payload[63:32]!=32'h02010000)
        $fatal(1,"preset KEY3");
    force dut.sw_stable=4'b0101;
    press(4'b0010);
    if (!request || request_type!=8'h14 ||
        request_payload[63:32]!=32'h05020303)
        $fatal(1,"brightness +2 absolute");
    force dut.sw_stable=4'b0110;
    press(4'b0100);
    if (!request || request_payload[63:32]!=32'h03020301)
        $fatal(1,"temperature -2 absolute");
    force dut.sw_stable=4'b0111;
    display=96'h0003020303010000ff1a0000;
    display_pulse=1;
    @(negedge clk); display_pulse=0;
    press(4'b0001);
    if (!request || request_type!=8'h15 ||
        request_payload!=64'h02000100ff100000)
        $fatal(1,"viewport clamping to -240");
    release dut.sw_stable;
    $display("PASS tb_secondary_main5e_keys");
    $finish;
end
initial begin #10000; $fatal(1,"timeout"); end
endmodule
