`timescale 1ns/1ps
module tb_source_dimensions;
reg clk=0, rst_n=0, wr_en=0;
always #10 clk=~clk;
reg [3:0] wr_index=0, rd_index=0;
reg [31:0] wr_dimensions=0;
wire [31:0] rd_dimensions;
reg [31:0] reference [0:4];
reg test_pass=0;
integer i,j,checks=0;
museum_source_dimensions dut(.*);
always @(posedge clk or negedge rst_n)
    if (!rst_n) for (j=0;j<5;j=j+1) reference[j]<=0;
    else if (wr_en && wr_index<5) reference[wr_index]<=wr_dimensions;
task check;
begin
    #1;
    if (rd_dimensions !== reference[rd_index])
        $fatal(1,"dimension mismatch slot=%0d got=%08x expected=%08x",rd_index,rd_dimensions,reference[rd_index]);
    checks=checks+1;
end
endtask
initial begin
    repeat(2) @(negedge clk);
    for (i=0;i<5;i=i+1) begin rd_index=i; check; end
    rst_n=1;
    for (i=0;i<20000;i=i+1) begin
        @(negedge clk);
        wr_en=$random; wr_index=$urandom_range(0,15);
        wr_dimensions=$random; rd_index=$urandom_range(0,4);
        check;
        @(posedge clk); check;
        // Exercise asynchronous reads, not merely clock-bound address changes.
        #2; rd_index=$urandom_range(0,4); check;
        if (i%97==0) begin
            #1; rst_n=0; check;
            #2; rst_n=1; check;
        end
    end
    test_pass=1;
    $display("PASS source dimensions: %0d comparisons, same-address writes, invalid writes, asynchronous reset/read",checks);
    $finish;
end
initial begin #1000000; $fatal(1,"timeout"); end
endmodule
