`timescale 1ns / 1ps
module tb_hdmi_edid_720p;
reg clk=0, rst_n=0, enable=1, scl=1, master_low=0;
always #10 clk=!clk;
wire slave_low;
wire sda = !(master_low || slave_low);
hdmi_edid_720p dut(.clk(clk),.rst_n(rst_n),.enable(enable),.scl(scl),.sda(sda),.sda_low(slave_low));
task start_i2c;
begin scl=0; master_low=0; #1000; scl=1; #1000; master_low=1; #1000; scl=0; end
endtask
task stop_i2c;
begin scl=0; master_low=1; #1000; scl=1; #1000; master_low=0; #1000; end
endtask
task send_byte;
input [7:0] value;
input expected_ack;
integer i;
begin
    for(i=7;i>=0;i=i-1) begin scl=0; master_low=!value[i]; #1000; scl=1; #1000; end
    scl=0; master_low=0; #1000; scl=1; #500;
    if (sda !== !expected_ack) $fatal(1,"ACK for %h expected %b got SDA %b",value,expected_ack,sda);
    #500; scl=0; #1000;
end
endtask
task read_byte;
output [7:0] value;
input acknowledge;
integer i;
begin
    master_low=0;
    for(i=7;i>=0;i=i-1) begin scl=0; #1000; scl=1; #500; value[i]=sda; #500; end
    scl=0; master_low=acknowledge; #1000; scl=1; #1000; scl=0; #1000; master_low=0;
end
endtask
integer i, sum0=0, sum1=0;
reg [7:0] data;
reg test_pass=0;
initial begin
    #200; rst_n=1; #1000;
    start_i2c; send_byte(8'ha0,1); send_byte(0,1);
    start_i2c; send_byte(8'ha1,1);
    for(i=0;i<256;i=i+1) begin
        read_byte(data,i!=255);
        if(data !== dut.edid_byte(i[7:0])) $fatal(1,"EDID byte %d expected %h got %h",i,dut.edid_byte(i[7:0]),data);
        if(i<128) sum0=sum0+data; else sum1=sum1+data;
    end
    stop_i2c;
    if(sum0%256 || sum1%256) $fatal(1,"EDID checksums");
    $display("PASS EDID both blocks, repeated start, sequential read and NACK");
    start_i2c; send_byte(8'h60,1); send_byte(1,1); stop_i2c;
    start_i2c; send_byte(8'ha1,0); stop_i2c;
    start_i2c; send_byte(8'h60,1); send_byte(0,1); stop_i2c;
    start_i2c; send_byte(8'ha0,1); send_byte(8'd128,1);
    start_i2c; send_byte(8'ha1,1); read_byte(data,0); stop_i2c;
    if(data!=2) $fatal(1,"CTA segment reset");
    start_i2c; send_byte(8'he8,0); stop_i2c;
    enable=0; #200;
    if(slave_low) $fatal(1,"disabled slave drives SDA");
    $display("PASS EDID segment bounds, offset128, unsupported address and disable");
    test_pass=1; $finish;
end
initial begin #10000000; $fatal(1,"EDID timeout"); end
endmodule
