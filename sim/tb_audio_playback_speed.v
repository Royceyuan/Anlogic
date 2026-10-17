`timescale 1ns/1ps
module tb_audio_playback_speed;
reg clk=0, clk50=0, rst=1, paused=0, mute=0, empty=0;
reg [1:0] speed=0;
always #6.666667 clk=~clk;
always #10 clk50=~clk50;
reg [31:0] data=32'h00010000;
wire rd, valid, toggle, active, underflow;
wire [15:0] left_sample,right_sample;
audio_pcm_player_48k #(.ENABLE_SPEED(1)) dut(
 .clk(clk),.rst(rst),.fifo_data(data),.fifo_valid(!empty),.fifo_empty(empty),
 .fifo_used(9'd300),.paused(paused),.switch_mute(mute),.speed_index(speed),
 .fifo_rd_en(rd),.sample_valid(valid),.sample_left(left_sample),
 .sample_right(right_sample),.frame_consumed_toggle(toggle),.active(active),.underflow(underflow));
integer reads=0,outputs=0,cdc_reads=0;
reg ff1=0,ff2=0,seen=0;
always @(posedge clk50) begin
 if(rst) begin ff1<=0;ff2<=0;seen<=0;cdc_reads<=0;end
 else begin ff1<=toggle;ff2<=ff1;seen<=ff2;if(ff2!=seen) cdc_reads<=cdc_reads+1;end
end
reg [31:0] expected_data=0;
reg expected_tick,expected_read;
reg [31:0] reference_phase=0;
wire [32:0] reference_next={1'b0,reference_phase}+48000;
always @(posedge clk) begin
 if(rst) begin data<=32'h00010000;reference_phase<=0;expected_data=0;end
 else begin
  expected_tick=reference_next>=75000000;
  reference_phase<=expected_tick ? reference_next-75000000 : reference_next;
  if(rd) data<=data+32'h00010001;
  expected_read=dut.source_tick&&active&&!empty&&!paused&&!mute;
  if(paused||mute||empty||!active) expected_data=0;
  else if(expected_read) expected_data=data;
  #1;
  if(valid!==expected_tick || rd!==expected_read) $fatal(1,"output rate/source read mismatch");
  if(valid) begin
   outputs=outputs+1;
   if({right_sample,left_sample}!==expected_data) $fatal(1,"decimated PCM/mute mismatch");
  end
  if(rd) reads=reads+1;
 end
end
integer saved_reads,saved_outputs,rate;
reg test_pass=0;
initial begin
 repeat(4) @(negedge clk);rst=0;
 for(rate=1;rate<=3;rate=rate+1) begin
  speed=rate-1;saved_reads=reads;saved_outputs=outputs;
  repeat(312500) @(negedge clk);
  if(outputs-saved_outputs!=200 || reads-saved_reads!=rate*200)
   $fatal(1,"speed %d: read=%d output=%d",rate,reads-saved_reads,outputs-saved_outputs);
 end
 paused=1;saved_reads=reads;speed=0;
 repeat(31250) @(negedge clk);
 if(reads!=saved_reads) $fatal(1,"pause consumed source frames");
 speed=2;paused=0;
 repeat(31250) @(negedge clk);
 if(reads-saved_reads!=60) $fatal(1,"resume lost speed selection");
 empty=1;repeat(110000) @(negedge clk);
 if(!underflow) $fatal(1,"starvation not reported");
 mute=1;saved_reads=reads;repeat(31250) @(negedge clk);
 if(reads!=saved_reads||underflow) $fatal(1,"mute consumed frames/kept error");
 mute=0;empty=0;speed=0;repeat(31250) @(negedge clk);
 repeat(6) @(negedge clk50);
 if(cdc_reads!=reads) $fatal(1,"50MHz source-frame CDC lost pulses %d/%d",cdc_reads,reads);
 test_pass=1;
 $display("PASS 1x/2x/3x: fixed48k, exact source counts/PCM, pause speed/resume, underflow/mute, 50MHz CDC");
 $finish;
end
endmodule
