`timescale 1ns/1ps
module tb_secondary_offline_overlay;
reg clk=0,rst_n=0,frame_tick=0,audio_valid=0,hs=1,vs=1,de=0;
reg [23:0] status=0,rgb=24'h406080;
reg [31:0] audio_data=32'h40002000;
reg [10:0] x=0;
reg [9:0] y=0;
wire visible,hs_o,vs_o,de_o;
wire [23:0] rgb_o;
integer fd,pixels,white,changed,bars,source_text,i,j,phase=0;
always #5 clk=~clk;
secondary_offline_overlay dut(.*);
task latch;
begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;repeat(4)@(negedge clk);end endtask
task capture;
input [1023:0] filename;
input integer expected;
begin
    fd=$fopen(filename,"wb");if(!fd)$fatal(1,"Cannot write overlay capture");
    $fwrite(fd,"P6\n1280 720\n255\n");pixels=0;white=0;changed=0;bars=0;source_text=0;
    for(j=0;j<720;j=j+1)for(i=0;i<1280;i=i+1)begin
        @(negedge clk);x=i;y=j;de=1;
        @(posedge clk);#1;
        if(de_o)begin
            $fwrite(fd,"%c%c%c",rgb_o[23:16],rgb_o[15:8],rgb_o[7:0]);pixels=pixels+1;
            if(rgb_o==24'hfff5dc)white=white+1;
            if(rgb_o==24'hfff5dc&&j>=96&&j<112)source_text=source_text+1;
            if(rgb_o==24'h4ec9e8||rgb_o==24'h5b7fff)bars=bars+1;
            if(rgb_o!=rgb)changed=changed+1;
            if(expected==0&&rgb_o!==rgb)$fatal(1,"Hidden overlay changed base pixel");
        end
    end
    @(negedge clk);de=0;
    repeat(5)begin @(posedge clk);#1;if(de_o)begin
        $fwrite(fd,"%c%c%c",rgb_o[23:16],rgb_o[15:8],rgb_o[7:0]);pixels=pixels+1;
    end end
    $fclose(fd);
    if(pixels!=1280*720)$fatal(1,"Raster dropped/added pixels %d",pixels);
    if(expected!=0&&(white<100||changed<500))$fatal(1,"Missing generated text/overlay");
    if(expected!=0&&!status[3]&&(bars<1000||bars>9792||source_text<100))$fatal(1,"Missing compact main-board bars or fourth OSD line");
end endtask
initial begin
    repeat(5)@(negedge clk);rst_n=1;
    status[5:4]=1;status[9:6]=4;status[12:10]=0;status[14:13]=1;status[15]=1;status[0]=1;status[17]=1;
    latch();audio_valid=1;repeat(800)@(negedge clk);audio_valid=0;repeat(3)@(negedge clk);latch();
    if(!dut.u_wave.display_valid)$fatal(1,"Main visualizer frame was not published");
    status[2]=1;repeat(3)@(negedge clk);
    if(!visible)$fatal(1,"SW4 gate changed inside a frame");
    status[2]=0;
    capture("_build_secondary/overlay_on.ppm",1);
    status[2]=1;latch();
    if(visible)$fatal(1,"SW4 did not hide at blanking");
    if(dut.u_wave.pause||!dut.u_wave.display_valid)$fatal(1,"SW4 reset/paused PCM history");
    capture("_build_secondary/overlay_off.ppm",0);
    status[3]=1;status[16]=0;latch();
    capture("_build_secondary/overlay_emergency.ppm",1);
    status[16]=1;latch();
    capture("_build_secondary/overlay_emergency_ready.ppm",0);
    status[2]=0;latch();
    capture("_build_secondary/overlay_emergency_ready_visible.ppm",0);
    if(dut.u_wave.pause!==1'b1)$fatal(1,"Emergency waveform was not suppressed");
    $display("PASS full 720p overlay raster: exact main-board bars, four OSD rows, frame-latched SW4 keeps history, emergency survives hide");$finish;
end
initial begin #60000000;$fatal(1,"Overlay timeout");end
endmodule
