`timescale 1ns/1ps
module tb_sd_native_read #(parameter integer CARD_DELAY_NS=14);
reg clk=0;always #5 clk=~clk;
reg rst_n=0,read_start=0;
wire sd_clk,card_clk;
wire [3:0] returned_dat;
// Model forwarded clock-pad delay, card tODLY, and input-pad return delay.
assign #4 card_clk=sd_clk;
assign #(CARD_DELAY_NS+2) returned_dat=dat;
tri1 sd_cmd;
reg card_cmd_o=1,card_cmd_oe=0;
reg [3:0] dat=15;
wire initialized,high_speed,busy,done,data_valid;
wire [7:0] data,error,stage;
wire [31:0] verified_blocks;
assign #(CARD_DELAY_NS+2) sd_cmd=card_cmd_oe?card_cmd_o:1'bz;
sd_native_read #(.POWER_CYCLES(20),.INIT_HALF_PERIOD(2),.DATA_TIMEOUT_CYCLES(20000)) dut(
    .clk(clk),.rst_n(rst_n),.read_start(read_start),.read_lba(32'd100),.read_blocks(32'd4),
    .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(returned_dat),.initialized(initialized),.high_speed(high_speed),
    .busy(busy),.done(done),.data_valid(data_valid),.data(data),.verified_blocks(verified_blocks),
    .error(error),.stage(stage));
integer failures=0,received=0,commands=0,capture_count=0,generation=0;
integer card_cycles=0,last_command_end=-100,last_response_end=-100;
reg [47:0] captured=0;
reg [47:0] pending_frame=0;
event command_event;
reg stream_enabled=0,corrupt_data=0,corrupt_response=0,reject_high_speed=0,drop_response=0,bad_end=0;
function [6:0] crc7;
    input [135:0] bits;
    input integer top;
    reg [6:0] c;
    integer i;
    begin
        c=0;
        for(i=top;i>=8;i=i-1) begin
            if(c[6]^bits[i]) c=(c<<1)^7'h09;else c=c<<1;
        end
        crc7=c;
    end
endfunction
function [15:0] crc16;
    input [15:0] c;
    input b;
    begin if(c[15]^b) crc16=(c<<1)^16'h1021;else crc16=c<<1;end
endfunction
function [7:0] sample_byte;
    input integer index;
    begin sample_byte=((index*73)^(index>>3)^8'hb7)&255;end
endfunction
task automatic reply;
    input [5:0] number;
    input [31:0] argument;
    input integer epoch;
    reg [135:0] bits;
    integer count,i;
    begin:response_task
        if(number==0) disable response_task;
        if(number==8&&drop_response) disable response_task;
        bits=0;count=48;
        case(number)
            8:bits={88'd0,2'b00,number,32'h1aa,8'h01};
            41:bits={88'd0,8'h3f,32'hc0ff8000,8'hff};
            2:begin bits={8'h3f,120'h123456789abcdef0123456789abcde,8'h01};count=136;end
            3:bits={88'd0,2'b00,number,32'h12340500,8'h01};
            6:bits={88'd0,2'b00,number,((argument==32'h80fffff1&&reject_high_speed)?32'h00400000:32'h00000900),8'h01};
            default:bits={88'd0,2'b00,number,32'h00000920,8'h01};
        endcase
        if(number!=41) bits[7:1]=crc7(bits,count==136?127:47);
        if(number==8&&corrupt_response) bits[1]=~bits[1];
        repeat(3) @(posedge card_clk);
        for(i=count-1;i>=0;i=i-1) begin
            if(epoch!=generation) disable response_task;
            card_cmd_oe=1;card_cmd_o=bits[i];@(posedge card_clk);
        end
        last_response_end=card_cycles;
        card_cmd_oe=0;card_cmd_o=1;
    end
endtask
task automatic block;
    input integer length,index,epoch;
    input is_switch;
    reg [15:0] c0,c1,c2,c3;
    reg [7:0] value;
    reg [3:0] nibble;
    integer i,j;
    begin:block_task
        c0=0;c1=0;c2=0;c3=0;
        @(posedge card_clk);dat=0;
        for(i=0;i<length;i=i+1) begin
            value=is_switch?(i==16?8'h01:8'h00):sample_byte(index*512+i);
            for(j=0;j<2;j=j+1) begin
                if(epoch!=generation||(!is_switch&&!stream_enabled)) begin dat=15;disable block_task;end
                nibble=j==0?value[7:4]:value[3:0];
                c0=crc16(c0,nibble[0]);c1=crc16(c1,nibble[1]);
                c2=crc16(c2,nibble[2]);c3=crc16(c3,nibble[3]);
                @(posedge card_clk);dat=nibble;
            end
        end
        if(corrupt_data&&!is_switch&&index==1) c2=c2^16'h0080;
        for(i=15;i>=0;i=i-1) begin @(posedge card_clk);dat={c3[i],c2[i],c1[i],c0[i]};end
        @(posedge card_clk);dat=bad_end&&!is_switch?4'h7:4'hf;
        @(posedge card_clk);dat=15;
    end
endtask
task automatic send_data;
    input integer epoch;
    input is_switch;
    integer i;
    begin:stream_task
        repeat(60) @(posedge card_clk);
        if(epoch!=generation) disable stream_task;
        if(is_switch) block(64,0,epoch,1);
        else for(i=0;i<8;i=i+1) begin
            if(epoch!=generation||!stream_enabled) disable stream_task;
            block(512,i,epoch,0);repeat(4) @(posedge card_clk);
        end
    end
endtask
task automatic command_seen;
    input [47:0] frame;
    input integer epoch;
    reg [5:0] number;
    reg [31:0] argument;
    begin
        number=frame[45:40];argument=frame[39:8];commands=commands+1;
        last_command_end=card_cycles;
        if(frame[47:46]!=1 || !frame[0] || crc7({88'd0,frame},47)!=frame[7:1]) begin
            $display("FAIL command CRC/frame %h",frame);failures=failures+1;
        end
        if(number==0 && frame!=48'h400000000095) begin $display("FAIL CMD0 known vector");failures=failures+1;end
        if(number==8 && frame!=48'h48000001aa87) begin $display("FAIL CMD8 known vector");failures=failures+1;end
        if(number==24||number==25) $fatal(1,"Unexpected SD write");
        if(number==18) begin
            if(argument!=100) $fatal(1,"Wrong SDHC block address");
            stream_enabled=1;
        end
        if(number==12) begin stream_enabled=0;dat=15;end
    end
endtask
always @(posedge card_clk) begin
    card_cycles=card_cycles+1;
    if(!rst_n) capture_count=0;
    else if(dut.cmd_oe) begin
        if(capture_count!=0||!sd_cmd) begin
            if(capture_count==0 &&
               (card_cycles-last_command_end<8 || card_cycles-last_response_end<8))
                $fatal(1,"Insufficient command gap: command=%0d response=%0d clocks",
                       card_cycles-last_command_end,card_cycles-last_response_end);
            captured={captured[46:0],sd_cmd};capture_count=capture_count+1;
            if(capture_count==48) begin
                capture_count=0;pending_frame=captured;command_seen(captured,generation);->command_event;
            end
        end
    end else capture_count=0;
end
// Keep command reception independent of the card's continuous data producer:
// CMD12 must be recognized while that producer is still sending another block.
always @(command_event) reply(pending_frame[45:40],pending_frame[39:8],generation);
always @(command_event) begin
    if(pending_frame[45:40]==18) send_data(generation,0);
    else if(pending_frame[45:40]==6&&pending_frame[39:8]==32'h80fffff1&&!reject_high_speed)
        send_data(generation,1);
end
always @(posedge clk) if(rst_n&&data_valid) begin
    if(data!==sample_byte(received)) begin
        $display("FAIL data byte %d got %h expected %h",received,data,sample_byte(received));failures=failures+1;
    end
    received=received+1;
end
task reset_card;
    begin
        @(negedge clk);rst_n=0;generation=generation+1;stream_enabled=0;
        card_cmd_oe=0;card_cmd_o=1;dat=15;capture_count=0;received=0;
        last_command_end=-100;last_response_end=-100;
        repeat(10) @(negedge clk);rst_n=1;
    end
endtask
task read_four;
    begin @(negedge clk);read_start=1;@(negedge clk);read_start=0;end
endtask
initial begin
    reset_card();wait(initialized||error!=0);
    if(error!=0||!high_speed) $fatal(1,"Initialization failed stage=%h error=%h",stage,error);
    read_four();wait(done||error!=0);
    if(error!=0||verified_blocks!=4||received<2048) $fatal(1,"Read failed %h blocks=%d bytes=%d",error,verified_blocks,received);
    $display("PASS native SDHC initialization, HS switch, CMD18/CMD12, four CRC-verified blocks");
    corrupt_data=1;reset_card();wait(initialized||error!=0);read_four();wait(error!=0);
    if(error!=8'ha3||verified_blocks!=1) $fatal(1,"Corrupt DAT2 CRC was accepted: %h %d",error,verified_blocks);
    $display("PASS independent DAT2 CRC rejection; invalid block not verified");
    corrupt_data=0;corrupt_response=1;reset_card();wait(error!=0);
    if(error!=8'h0b||initialized) $fatal(1,"Corrupt response CRC was accepted: %h",error);
    $display("PASS response CRC rejection");
    corrupt_response=0;reject_high_speed=1;reset_card();wait(initialized||error!=0);
    if(error!=0||high_speed) $fatal(1,"Default-speed fallback failed");
    read_four();wait(done||error!=0);if(error!=0||verified_blocks!=4) $fatal(1,"Default-speed read failed");
    $display("PASS unsupported HS safely remains at default 25 MHz");
    reject_high_speed=0;bad_end=1;reset_card();wait(initialized||error!=0);read_four();wait(error!=0);
    if(error!=8'ha2||verified_blocks!=0) $fatal(1,"Bad data end bit accepted");
    $display("PASS bad data end bit rejection");
    bad_end=0;drop_response=1;reset_card();wait(error!=0);
    if(error!=8'h09||initialized) $fatal(1,"Missing response did not time out");
    $display("PASS missing response timeout");
    if(failures!=0) $fatal(1,"FAIL failures=%d",failures);
    $display("PASS sd_native_read all checks");$finish;
end
initial begin #20_000_000;$fatal(1,"Test timeout stage=%h error=%h initialized=%d",stage,error,initialized);end
endmodule
