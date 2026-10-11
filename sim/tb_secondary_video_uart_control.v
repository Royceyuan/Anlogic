`timescale 1ns/1ps
module tb_secondary_video_uart_control;
parameter LINK_TEST=1;
reg clk=0,rst_n=0,rxd=1,ready=1;
reg [7:0] museum_artifact=2,museum_state=0,museum_phase=0;
always #10 clk=!clk;
wire txd,enabled,armed;
secondary_video_uart_control #(.BAUD_DIV(8),.CLOCKS_PER_MS(200),.WATCHDOG_MS(40),.MUSEUM_LINK(LINK_TEST)) dut(
    .clk(clk),.rst_n(rst_n),.uart_rxd(rxd),.input_ready(ready),
    .external_selected(enabled),.output_muted(1'b0),.uart_txd(txd),.play_enabled(enabled),
    .link_armed(armed),
    .museum_artifact(museum_artifact),.museum_state(museum_state),.museum_phase(museum_phase));
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
reg [7:0] replies[0:399];
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
task context_query;
input [7:0] seq;
integer base,j;
reg [7:0] c;
begin
    base=reply_count;packet(5,seq,0);wait(reply_count>=base+8);
    c=0;for(j=0;j<7;j=j+1)c=crc(c,replies[base+j]);
    if(replies[base]!=8'h5a||replies[base+1]!=8'ha6||replies[base+2]!=seq||replies[base+7]!=c||
       replies[base+4]!=museum_artifact||replies[base+5]!=museum_state||replies[base+6]!=museum_phase)
        $fatal(1,"bad context snapshot/header/CRC");
end endtask
reg test_pass=0;
reg [7:0] hb_mode=3,hb_emergency=1,hb_error=0;
reg hb_busy=1;
wire decoded_recovery;
secondary_pc_recovery_decode hb_decode(.mode(hb_mode),.emergency(hb_emergency),
    .error(hb_error),.app_busy(hb_busy),.recovery(decoded_recovery));
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
    if(LINK_TEST) begin
        museum_state=8'h01;exchange(8'h22,29,0,0);
        if(!armed||enabled) $fatal(1,"warm hint must not display video");
        exchange(4,29,0,0);exchange(2,29,0,0);
        if(!armed) $fatal(1,"warm return hint lost before explicit release");
        exchange(7,29,0,0);if(armed) $fatal(1,"release did not clear warm hint");
        museum_state=0;
        context_query(30);
        exchange(8'h12,31,0,1);
        museum_state=8'h03;museum_phase=3;context_query(32);
        exchange(8'h11,33,0,1);exchange(8'h12,34,1,0);
        museum_state=8'h07;context_query(35);
        if(!enabled) $fatal(1,"pause incorrectly cancelled video lease");
        museum_artifact=3;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"old artifact lease survived actual artifact change");
        exchange(8'h12,36,0,1);exchange(8'h13,37,1,0);
        museum_state=8'h06;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"network loss did not revoke linked video");
        museum_state=8'h03;exchange(1,38,1,0);
        museum_state=8'h0b;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"emergency did not revoke MANUAL authorization");
        exchange(1,39,0,1);exchange(8'h13,40,0,1);context_query(41);
        museum_state=8'h03;repeat(20) @(negedge clk);
        if(enabled) $fatal(1,"emergency clear automatically restored old video");
        exchange(8'h13,42,1,0);museum_state=8'h43;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"application recovery did not revoke video");
        museum_state=8'h01;exchange(8'h13,43,0,1);
        $display("PASS UART context CRC, actual artifact, pause, loss, emergency priority, no old resume and recovery");
        museum_state=8'h01;exchange(8'h23,44,0,0);repeat(9000) @(negedge clk);
        if(armed||enabled) $fatal(1,"warm hint survived PC loss");
        exchange(8'h23,45,0,0);museum_state=8'h09;repeat(3) @(negedge clk);
        if(armed) $fatal(1,"emergency retained intro suppression");
        $display("PASS UART warm hint never authorizes AV; release, timeout and emergency restore local policy");
        museum_state=8'h01;exchange(6,46,0,1);
        museum_state=8'h09;ready=0;exchange(6,47,0,1);ready=1;
        museum_state=8'h08;exchange(6,48,0,1);
        museum_state=8'h49;exchange(6,49,0,1);
        museum_state=8'h09;exchange(6,50,1,0);exchange(6,50,1,0);
        if(!replies[reply_count-2][5]||armed) $fatal(1,"emergency flag missing or ordinary hint retained");
        exchange(4,51,1,0);exchange(1,52,1,1);
        if(!dut.emergency_lease) $fatal(1,"ordinary START replaced emergency lease");
        museum_state=8'h01;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"emergency video survived emergency clear");
        exchange(3,53,0,0);if(replies[reply_count-2][5]) $fatal(1,"stale emergency authorized flag");
        museum_state=8'h09;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"emergency re-entry reused old authorization");
        $display("PASS emergency-only START: fresh state/source required; ordinary START blocked; clear revokes");
        exchange(6,54,1,0);ready=0;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"emergency input loss retained video");
        ready=1;repeat(3) @(negedge clk);if(enabled) $fatal(1,"input reconnect reused emergency lease");
        exchange(6,55,1,0);museum_state=8'h08;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"emergency network loss retained video");
        museum_state=8'h09;repeat(3) @(negedge clk);if(enabled) $fatal(1,"network reconnect reused emergency lease");
        exchange(6,56,1,0);museum_state=8'h49;repeat(3) @(negedge clk);
        if(enabled) $fatal(1,"recovery retained emergency video");
        museum_state=8'h09;repeat(3) @(negedge clk);if(enabled) $fatal(1,"recovery clear reused emergency lease");
        $display("PASS emergency video loss/recovery returns local; fresh START required after reconnect");
        exchange(6,57,1,0);repeat(9000) @(negedge clk);
        if(enabled) $fatal(1,"PC watchdog retained emergency video");
        exchange(6,58,1,0);exchange(2,59,0,0);
        exchange(6,60,1,0);exchange(7,61,0,0);
        $display("PASS emergency lease watchdog, STOP and release preserve static fallback");
        #1;museum_state={1'b0,decoded_recovery,2'b00,(hb_emergency!=0),2'b00,1'b1};
        exchange(6,63,1,0);
        hb_mode=1;hb_emergency=0;#1;
        museum_state={1'b0,decoded_recovery,2'b00,(hb_emergency!=0),2'b00,1'b1};
        repeat(3) @(negedge clk);if(enabled) $fatal(1,"post-emergency recovery retained grant");
        exchange(6,64,0,1);
        hb_mode=3;hb_emergency=1;hb_error=3;#1;
        museum_state={1'b0,decoded_recovery,2'b00,(hb_emergency!=0),2'b00,1'b1};
        exchange(6,65,0,1);
        hb_error=0;#1;museum_state={1'b0,decoded_recovery,2'b00,(hb_emergency!=0),2'b00,1'b1};
        exchange(6,66,1,0);exchange(2,67,0,0);
        $display("PASS actual heartbeat busy -> normalized state -> emergency UART grant; real error/exit blocked");
        force dut.tx_ready=0;packet(2,68,0);repeat(10) @(negedge clk);
        packet(6,69,0);repeat(10) @(negedge clk);
        if(!enabled) $fatal(1,"urgent emergency START waited for old STOP reply");
        base=reply_count;release dut.tx_ready;wait(reply_count>=base+5);
        if(replies[base+2]!=69||!replies[base+3][5]) $fatal(1,"old STOP reply replaced urgent emergency ACK");
        exchange(2,70,0,0);
        $display("PASS cached emergency START supersedes pending STOP without waiting for its ACK");
    end else begin
        exchange(6,62,0,1);
    end
    rst_n=0;repeat(5) @(negedge clk);if(enabled||txd!==1) $fatal(1,"reset unsafe");
    test_pass=1;$finish;
end
initial begin #3000000;$fatal(1,"UART test timeout bytes=%d state=%d",reply_count,dut.rx_state);end
endmodule
