`timescale 1ns/1ps
module tb_hdmi_local_reset;
reg pixel_clk=0, serial_clk=0, pixel_rst=1, serial_rst=1;
reg [9:0] ch0=0, ch1=0, ch2=0, clock_data=10'b1111100000;
wire [3:0] actual, reference;
reg test_pass=0;
integer i;
always #6.666 pixel_clk=~pixel_clk;
always #1.333 serial_clk=~serial_clk;
always @(negedge pixel_clk) begin
    ch0=$random; ch1=$random; ch2=$random;
end
hdmi_audio_video_phy dut (
    .I_pixel_clk(pixel_clk),.I_serial_clk(serial_clk),
    .I_pixel_rst(pixel_rst),.I_serial_rst(serial_rst),
    .I_tmds_channel_0(ch0),.I_tmds_channel_1(ch1),.I_tmds_channel_2(ch2),
    .I_tmds_channel_clk(clock_data),.O_tmds_ch0_p(actual[0]),
    .O_tmds_ch1_p(actual[1]),.O_tmds_ch2_p(actual[2]),.O_tmds_clk_p(actual[3]));
hdmi_audio_video_phy_ref baseline (
    .I_pixel_clk(pixel_clk),.I_serial_clk(serial_clk),
    .I_pixel_rst(pixel_rst),.I_serial_rst(serial_rst),
    .I_tmds_channel_0(ch0),.I_tmds_channel_1(ch1),.I_tmds_channel_2(ch2),
    .I_tmds_channel_clk(clock_data),.O_tmds_ch0_p(reference[0]),
    .O_tmds_ch1_p(reference[1]),.O_tmds_ch2_p(reference[2]),.O_tmds_clk_p(reference[3]));
always @(negedge serial_clk) begin
    #0.01;
    if(actual!==reference) $fatal(1,"HDMI serialization changed by reset preservation");
end
initial begin
    #10; pixel_rst=0; serial_rst=0;
    for(i=0;i<100;i=i+1) begin
        #37.1; serial_rst=1; #0.1;
        if({dut.serial_rst_n_ch0,dut.serial_rst_n_ch1,
            dut.serial_rst_n_ch2,dut.serial_rst_n_clk}!==4'b0000)
            $fatal(1,"local reset assertion is not asynchronous");
        #5.7; serial_rst=0;
        @(posedge serial_clk); #0.1;
        if(dut.serial_rst_n_ch0!==0) $fatal(1,"reset released before two clocks");
        @(posedge serial_clk); #0.1;
        if({dut.serial_rst_n_ch0,dut.serial_rst_n_ch1,
            dut.serial_rst_n_ch2,dut.serial_rst_n_clk}!==4'b1111)
            $fatal(1,"lane reset releases are not aligned");
    end
    test_pass=1;
    $display("PASS preserved HDMI local resets: 100 async pulses and bitstream equivalence");
    $finish;
end
endmodule

// Digital-only ODDR model; analog HDMI signaling still requires board testing.
module EG_LOGIC_ODDR(input clk,rst,d0,d1,output reg q);
always @(clk) q <= rst ? 1'b0 : clk ? d0 : d1;
endmodule
