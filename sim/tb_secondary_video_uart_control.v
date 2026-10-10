`timescale 1ns/1ps
module tb_secondary_video_uart_control;
reg clk=0,rst_n=0,rxd=1,ready=1;
always #10 clk=!clk;
wire txd,enabled;
secondary_video_uart_control #(.BAUD_DIV(8),.CLOCKS_PER_MS(200),.WATCHDOG_MS(40)) dut(
    .clk(clk),.rst_n(rst_n),.uart_rxd(rxd),.input_ready(ready),
    .external_selected(enabled),.output_muted(1'b0),.uart_txd(txd),.play_enabled(enabled));
wire [7:0] reply_byte;
wire reply_valid;
secondary_uart_rx #(.BAUD_DIV(8)) reply_rx(
    .clk(clk),.rst_n(rst_n),.rxd(txd),.data(reply_byte),.valid(reply_valid));
function [7:0] crc;
input [7:0] c,b;
reg [7:0] v;
integer i;
begin v=c^b;for(i=0;i<8;i=i+1) v=v[7] ? (v<<1)^8'h07 : v<<1;crc=v;end
endfunction
reg [7:0] replies[0:199];
integer reply_count=0;
always @(posedge clk) if(reply_valid) begin
    replies[reply_count]=reply_byte;reply_count=reply_count+1;
end
task send_byte;
input [7:0] value;
input bad_stop;
integer bit;
begin
    @(negedge clk);rxd=0;repeat(8) @(negedge clk);
    for(bit=0;bit<8;bit=bit+1) begin rxd=value[bit];repeat(8) @(negedge clk);end
    rxd=!bad_stop;repeat(8) @(negedge clk);rxd=1;repeat(8) @(negedge clk);
end endtask
task packet;
input [7:0] command,seq;
input bad_crc;
reg [7:0] c;
begin
    c=crc(crc(crc(crc(0,8'ha5),8'h5a),command),seq);
    send_byte(8'ha5,0);send_byte(8'h5a,0);send_byte(command,0);send_byte(seq,0);
    send_byte(c^bad_crc,0);
end endtask
task exchange;
input [7:0] command,seq;
input permit,reject;
integer base;
reg [7:0] c;
begin
    base=reply_count;packet(command,seq,0);wait(reply_count>=base+5);
    c=crc(crc(crc(crc(0,replies[base]),replies[base+1]),replies[base+2]),replies[base+3]);
    if(replies[base]!=8'h5a||replies[base+1]!=8'ha5||replies[base+2]!=seq||replies[base+4]!=c)
        $fatal(1,"bad ACK header/sequence/CRC");
    if(replies[base+3][3]!==permit||replies[base+3][7]!==reject||enabled!==permit)
        $fatal(1,"bad permit/rejection flags seq=%d flags=%h enabled=%b",seq,replies[base+3],enabled);
end endtask
reg test_pass=0;
integer i,base;
reg [7:0] golden;
initial begin
    golden=0;
    for(i=8'h31;i<=8'h39;i=i+1) golden=crc(golden,i);
    if(golden!=8'hf4) $fatal(1,"CRC8 known vector");
    #100;rst_n=1;repeat(30) @(negedge clk);
    if(enabled) $fatal(1,"connected HDMI auto-authorized at boot");
    exchange(3,1,0,0);
    $display("PASS UART boot/query keep HDMI local while input is valid");
    base=reply_count;packet(1,2,1);repeat(500) @(negedge clk);
    if(enabled||reply_count!=base) $fatal(1,"bad CRC accepted");
    send_byte(8'ha5,0);send_byte(8'h5a,0);repeat(2400) @(negedge clk);
    exchange(3,3,0,0);
    $display("PASS UART malformed CRC and truncated frame rejected/resynchronized");
    ready=0;exchange(1,4,0,1);ready=1;
    exchange(1,5,1,0);exchange(1,5,1,0);
    $display("PASS UART START requires valid HDMI and duplicate START is idempotent");
    repeat(4000) @(negedge clk);exchange(4,6,1,0);
    repeat(4000) @(negedge clk);if(!enabled) $fatal(1,"heartbeat did not retain paused video");
    exchange(99,7,1,1);exchange(2,8,0,0);exchange(2,8,0,0);
    $display("PASS UART keepalive/reject/STOP/duplicate STOP and status ACK");
    exchange(1,9,1,0);ready=0;repeat(3) @(negedge clk);
    if(enabled) $fatal(1,"input loss did not cancel authorization");
    ready=1;repeat(20) @(negedge clk);if(enabled) $fatal(1,"reconnect displayed desktop without new authorization");
    $display("PASS UART input loss cancels lease and reconnect remains local");
    exchange(1,10,1,0);
    repeat(5) exchange(3,11,1,0);
    repeat(9000) @(negedge clk);if(enabled) $fatal(1,"PC loss did not expire lease");
    exchange(3,12,0,0);
    $display("PASS UART PC loss expires lease; QUERY cannot authorize or keep it alive");
    base=reply_count;
    send_byte(8'ha5,0);send_byte(8'h5a,0);send_byte(1,0);send_byte(13,0);
    send_byte(crc(crc(crc(crc(0,8'ha5),8'h5a),1),13),1);
    repeat(2400) @(negedge clk);
    if(enabled||reply_count!=base) $fatal(1,"bad UART stop bit accepted");
    exchange(3,14,0,0);
    $display("PASS UART framing error rejected and next valid command recovers");
    force dut.tx_ready=0;
    packet(1,20,0);repeat(10) @(negedge clk);if(!enabled) $fatal(1,"START blocked by TX");
    packet(2,21,0);repeat(10) @(negedge clk);if(enabled) $fatal(1,"STOP blocked by TX");
    base=reply_count;release dut.tx_ready;wait(reply_count>=base+5);
    if(replies[base+2]!=21||replies[base+3][3]) $fatal(1,"stale queued ACK after STOP");
    $display("PASS UART stopped reply channel cannot block STOP or retain stale authorization");
    rst_n=0;repeat(5) @(negedge clk);if(enabled||txd!==1) $fatal(1,"reset unsafe");
    test_pass=1;$finish;
end
initial begin #3000000;$fatal(1,"UART test timeout bytes=%d state=%d",reply_count,dut.rx_state);end
endmodule
