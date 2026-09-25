`timescale 1ns/1ps
module tb_mbp1_media_bridge;
reg net_clk=0, media_clk=0, rst=1;
always #4 net_clk=~net_clk;
always #10 media_clk=~media_clk;
reg [7:0] media_mode=8'd2;
reg [127:0] media_heartbeat=128'h1234;
reg [63:0] media_playback=64'h5678;
reg [95:0] media_display=96'h9abc;
reg [127:0] media_diagnostic=128'hdef0;
wire [7:0] net_mode;
wire [127:0] net_heartbeat,net_diagnostic;
wire [63:0] net_playback;
wire [95:0] net_display;
reg net_command_valid=0;
reg [7:0] net_command_type=8'h14;
reg [63:0] net_command_payload=64'h0102030405060708;
wire net_command_done,media_command_valid;
wire [7:0] net_command_result,media_command_type;
wire [63:0] media_command_payload;
reg media_command_done=0;
reg [7:0] media_command_result=8'd5;
integer commands=0;

mbp1_media_bridge #(.REFRESH_CYCLES(8)) dut (
    .net_clk(net_clk),.media_clk(media_clk),.rst(rst),
    .media_mode(media_mode),.media_heartbeat(media_heartbeat),
    .media_playback(media_playback),.media_display(media_display),
    .media_diagnostic(media_diagnostic),.net_mode(net_mode),
    .net_heartbeat(net_heartbeat),.net_playback(net_playback),
    .net_display(net_display),.net_diagnostic(net_diagnostic),
    .net_command_valid(net_command_valid),.net_command_type(net_command_type),
    .net_command_payload(net_command_payload),.net_command_done(net_command_done),
    .net_command_result(net_command_result),
    .media_command_valid(media_command_valid),
    .media_command_type(media_command_type),
    .media_command_payload(media_command_payload),
    .media_command_done(media_command_done),
    .media_command_result(media_command_result)
);
always @(posedge media_clk) begin
    media_command_done <= media_command_valid;
    if (media_command_valid) begin
        commands=commands+1;
        if (media_command_type!=8'h14 ||
            media_command_payload!=64'h0102030405060708)
            $fatal(1,"command CDC");
    end
end
initial begin
    repeat(3) @(negedge net_clk); rst=0;
    wait(net_mode==2 && net_heartbeat==128'h1234 &&
         net_playback==64'h5678 && net_display==96'h9abc &&
         net_diagnostic==128'hdef0);
    @(negedge net_clk); net_command_valid=1;
    wait(net_command_done);
    if(net_command_result!=5 || commands!=1) $fatal(1,"result CDC");
    @(negedge net_clk); net_command_valid=0;
    repeat(20) @(negedge net_clk);
    if(commands!=1) $fatal(1,"duplicate command");
    $display("PASS tb_mbp1_media_bridge"); $finish;
end
initial begin #100000; $fatal(1,"timeout"); end
endmodule
