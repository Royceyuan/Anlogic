`timescale 1ns / 1ps
module tb_museum_writer_abort;
reg clk=0,rst_n=0,row_valid=0,abort=0,write_finish=0;
wire row_ready,write_req,write_en,abort_done,frame_done,error;
wire [31:0] write_data;
wire [7:0] write_base_addr,write_len;
integer words=0,cycles=0;
always #10 clk=~clk;
bmp_sdram_row_writer #(
 .WIDTH(8),.HEIGHT(1),.ROW_BITS(1),.ADDR_BITS(8),
 .WORDS_PER_ROW(4),.BURST_WORDS(4),.ENABLE_ABORT(1)
) dut (
 .clk(clk),.rst_n(rst_n),.start(1'b0),
 .row_valid(row_valid),.row_index(1'b0),.row_pixel(16'h1234),
 .row_last(1'b0),.row_ready(row_ready),
 .frame_base_addr(8'd0),.overview_base_addr(8'd0),
 .overview_frame_index(4'hf),
 .write_req(write_req),.write_req_ack(write_req),
 .write_en(write_en),.write_data(write_data),
 .write_base_addr(write_base_addr),.write_len(write_len),
 .write_fifo_full(1'b0),.write_finish(write_finish),
 .abort(abort),.abort_done(abort_done),
 .frame_done(frame_done),.error(error)
);
always @(posedge clk) begin
 write_finish<=0;
 if(write_en) begin
  if(words==0 && write_data!==32'h12341234)
   $fatal(1,"initial data incorrect %h",write_data);
  if(words>0 && write_data!==32'd0)
   $fatal(1,"aborted burst has stale data %h",write_data);
  words=words+1;
  if(words==1) abort<=1;
  if(words==4) write_finish<=1;
 end
end
initial begin
 repeat(3) @(negedge clk);rst_n=1;row_valid=1;
 while(!(abort_done && abort && words==4) && cycles<300) begin
  @(negedge clk);cycles=cycles+1;
 end
 if(cycles>=300 || error || frame_done)
  $fatal(1,"abort did not finish safely: words=%d done=%b",words,abort_done);
 $display("PASS tb_museum_writer_abort zero-padded accepted burst");
 $finish;
end
endmodule
