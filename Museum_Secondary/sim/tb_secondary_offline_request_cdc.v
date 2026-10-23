`timescale 1ns/1ps
module tb_secondary_offline_request_cdc;
reg source_clk=0,target_clk=0;always #11 source_clk=~source_clk;always #5 target_clk=~target_clk;
reg source_rst_n=0,target_rst_n=0;
reg [40:0] source_data={32'd0,8'hff,1'b1};
wire [40:0] target_data;
integer i,updates=0;
reg [40:0] previous={32'd0,8'hff,1'b1};
secondary_offline_request_cdc dut(.*);
always @(negedge target_clk)if(target_rst_n&&target_data!=previous)begin
    if(target_data[8:1]!=target_data[16:9]||target_data[0]!=target_data[9])
        $fatal(1,"Torn file/generation/pause snapshot %h",target_data);
    previous=target_data;updates=updates+1;
end
initial begin
    repeat(5)@(negedge source_clk);source_rst_n=1;target_rst_n=1;
    for(i=1;i<=200;i=i+1)begin
        @(negedge source_clk);source_data={32'(i),8'(i),1'(i)};
    end
    repeat(40)@(negedge source_clk);
    if(target_data!==source_data||updates<10)$fatal(1,"Latest snapshot not delivered");
    $display("PASS bundled 50/100MHz-equivalent snapshot CDC, rapid-update coalescing and latest state");$finish;
end
initial begin #30000;$fatal(1,"CDC timeout");end
endmodule
