`timescale 1ns/1ps
module tb_mbp1_endpoint_equivalence;
parameter HOLD=0;
reg clk=0;
always #5 clk=~clk;
reg rst=1, rx_valid=0, tx_ready=0, tx_ack=0;
reg test_pass=0;
reg [7:0] rx_data=0;
reg [15:0] rx_length=0;
reg [31:0] boot=1;
reg phy=1, changed=0, done=0;
reg [7:0] mode=0, result=0;
reg [127:0] heartbeat=0, diagnostic=0;
reg [63:0] playback=0;
reg [95:0] display_data=0;
wire [1:0] request, valid, command_valid, alive;
wire [7:0] data[0:1], command_type[0:1];
wire [15:0] length[0:1], crc_errors[0:1], drops[0:1], retries[0:1];
wire [31:0] command_seq[0:1];
wire [63:0] command_payload[0:1];
integer ticks=0, packets=0, bytes=0, commands=0, resets=0, n, j;
reg [7:0] packet[0:63];
reg [15:0] crc;
function [15:0] crc_byte;
 input [15:0] prior; input [7:0] value;
 reg [15:0] c; integer b;
 begin
  c=prior^{value,8'd0};
  for(b=0;b<8;b=b+1) c=c[15]?((c<<1)^16'h1021):(c<<1);
  crc_byte=c;
 end
endfunction

mbp1_main_endpoint #(.CLOCKS_PER_MS(2),.ENABLE_CONTROL(1),.ENABLE_PLAYBACK(1),.HOLD_TX_FIELDS(HOLD)) dut (
 .clk(clk),.rst(rst),.rx_data(rx_data),.rx_valid(rx_valid),.rx_length(rx_length),
 .tx_ready(tx_ready),.tx_ack(tx_ack),.tx_request(request[0]),.tx_data(data[0]),.tx_valid(valid[0]),.tx_length(length[0]),
 .local_boot_id(boot),.phy_link(phy),.main_mode(mode),.heartbeat_payload(heartbeat),.playback_payload(playback),
 .display_payload(display_data),.display_changed(changed),.diagnostic_payload(diagnostic),
 .command_valid(command_valid[0]),.command_type(command_type[0]),.command_seq(command_seq[0]),.command_payload(command_payload[0]),
 .command_done(done),.command_result(result),.peer_alive(alive[0]),.crc_error_count(crc_errors[0]),.drop_count(drops[0]),.retry_count(retries[0]));
mbp1_main_endpoint_reference #(.CLOCKS_PER_MS(2),.ENABLE_CONTROL(1),.ENABLE_PLAYBACK(1),.HOLD_TX_FIELDS(HOLD)) reference (
 .clk(clk),.rst(rst),.rx_data(rx_data),.rx_valid(rx_valid),.rx_length(rx_length),
 .tx_ready(tx_ready),.tx_ack(tx_ack),.tx_request(request[1]),.tx_data(data[1]),.tx_valid(valid[1]),.tx_length(length[1]),
 .local_boot_id(boot),.phy_link(phy),.main_mode(mode),.heartbeat_payload(heartbeat),.playback_payload(playback),
 .display_payload(display_data),.display_changed(changed),.diagnostic_payload(diagnostic),
 .command_valid(command_valid[1]),.command_type(command_type[1]),.command_seq(command_seq[1]),.command_payload(command_payload[1]),
 .command_done(done),.command_result(result),.peer_alive(alive[1]),.crc_error_count(crc_errors[1]),.drop_count(drops[1]),.retry_count(retries[1]));

always @(posedge clk) begin
 if(valid[0]) bytes=bytes+1;
 if(request[0] && tx_ack) packets=packets+1;
 if(command_valid[0] && done) commands=commands+1;
end
always @(negedge clk) begin
 if(ticks>2 && {request[0],valid[0],data[0],length[0],command_valid[0],command_type[0],command_seq[0],command_payload[0],alive[0],crc_errors[0],drops[0],retries[0]} !==
               {request[1],valid[1],data[1],length[1],command_valid[1],command_type[1],command_seq[1],command_payload[1],alive[1],crc_errors[1],drops[1],retries[1]})
  $fatal(1,"endpoint cycle mismatch tick=%0d hold=%0d",ticks,HOLD);
 ticks=ticks+1;
 // Change status even during TX, and delay acceptance to exercise snapshots.
 tx_ready=($random & 3)!=0;
 tx_ack=request[0] && (($random & 3)==0);
 done=command_valid[0] && (($random & 3)==0);
 result=$random;
 heartbeat={$random,$random,$random,$random};
 diagnostic={$random,$random,$random,$random};
 display_data={$random,$random,$random};
 mode=$random;
 changed=(ticks%53)==0;
 if(ticks%701==0) playback={$random,$random};
end

initial begin
 repeat(4) @(posedge clk); #1 rst=0;
 for(n=0;n<120;n=n+1) begin
  for(j=0;j<64;j=j+1) packet[j]=0;
  packet[0]=8'h4d; packet[1]=8'h42; packet[2]=1;
  case(n%6)
   0: begin packet[3]=1; rx_length=34; packet[20]=2; packet[21]=2; packet[22]=1; packet[23]=1; end
   1: begin packet[3]=3; rx_length=22; end
   2: begin packet[3]=8'h13; rx_length=26; packet[21]=1; end
   3: begin packet[3]=8'h14; rx_length=30; end
   4: begin packet[3]=8'h15; rx_length=30; end
   5: begin packet[3]=2; rx_length=38; end
  endcase
  packet[4]=1; packet[5]=20; packet[7]=rx_length-22;
  packet[11]=n; packet[15]=n/30+1;
  // Same-session duplicates and old IDs must retain the original ACK behavior.
  if(n%6==3) packet[11]=n-1;
  if(n%18==16) packet[11]=0;
  crc=16'hffff;
  for(j=0;j<rx_length-2;j=j+1) crc=crc_byte(crc,packet[j]);
  packet[rx_length-2]=crc[15:8]; packet[rx_length-1]=crc[7:0];
  if(n%13==12) packet[rx_length-1]=~packet[rx_length-1];
  for(j=0;j<rx_length;j=j+1) begin
   @(posedge clk); #1 rx_valid=1; rx_data=packet[j];
  end
  @(posedge clk); #1 rx_valid=0;
  repeat(80) @(posedge clk);
  if(n%19==18) begin
   #2 rst=1; resets=resets+1;
   repeat(3) @(posedge clk); #2 rst=0; boot=boot+1;
  end
 end
 repeat(6000) @(posedge clk);
 if(packets<20 || bytes<600 || commands<10 || resets<6)
  $fatal(1,"insufficient activity packets=%0d bytes=%0d commands=%0d resets=%0d",packets,bytes,commands,resets);
 $display("PASS endpoint cycle equivalence hold=%0d packets=%0d bytes=%0d commands=%0d resets=%0d",HOLD,packets,bytes,commands,resets);
 test_pass=1;
 $finish;
end
initial begin #1000000; $fatal(1,"timeout"); end
endmodule
