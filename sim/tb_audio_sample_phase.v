`timescale 1ns/1ps
module tb_audio_sample_phase;
reg clk=0, rst=1, paused=0, mute=0, empty=0;
always #5 clk=~clk;
wire [5:0] tick, consumed, valid, active, underflow;
wire [15:0] left_sample[0:5], right_sample[0:5];
genvar n;
generate for(n=0;n<6;n=n+1) begin:g_player
    localparam integer CLOCK_HZ=n%3==0 ? 75000000 : n%3==1 ? 74250000 : 75000001;
    reg [31:0] reference_phase=0;
    wire [32:0] reference_next={1'b0,reference_phase}+48000;
    audio_pcm_player_48k #(.ENABLE_SPEED(n>=3)) dut(
        .clk(clk),.rst(rst),.fifo_data(32'h1234abcd),.fifo_valid(!empty),
        .fifo_empty(empty),.fifo_used(9'd300),.paused(paused),.switch_mute(mute),
        .speed_index(2'd0),
        .fifo_rd_en(consumed[n]),.sample_valid(valid[n]),
        .sample_left(left_sample[n]),.sample_right(right_sample[n]),
        .frame_consumed_toggle(),.active(active[n]),.underflow(underflow[n]));
    defparam dut.PIXEL_CLK_HZ=CLOCK_HZ;
    assign tick[n]=reference_next>=CLOCK_HZ;
    always @(posedge clk) begin
        if(rst) reference_phase<=0;
        else begin
            if(dut.sample_tick!==tick[n]) $fatal(1,"sample edge mismatch clock=%d",CLOCK_HZ);
            reference_phase<=tick[n] ? reference_next-CLOCK_HZ : reference_next;
        end
    end
end endgenerate
generate for(n=0;n<3;n=n+1) begin:g_alarm
    localparam integer CLOCK_HZ=n==0 ? 75000000 : n==1 ? 74250000 : 75000001;
    reg [31:0] reference_phase=0;
    reg expected_alarm;
    wire alarm_valid;
    emergency_alarm_48k #(.CLK_HZ(CLOCK_HZ)) dut(
        .clk(clk),.rst_n(!rst),.enable(!mute),.sample_valid(alarm_valid),
        .sample_left(),.sample_right());
    always @(posedge clk) begin
        if(rst) reference_phase<=0;
        else begin
            expected_alarm=!mute && reference_phase>=CLOCK_HZ-48000;
            reference_phase<=mute ? 0 : expected_alarm ?
                             reference_phase-(CLOCK_HZ-48000) : reference_phase+48000;
            #1;
            if(alarm_valid!==expected_alarm) $fatal(1,"alarm sample edge mismatch %d",CLOCK_HZ);
        end
    end
end endgenerate
integer cycle, i;
reg [5:0] expected_read, expected_valid;
reg test_pass=0;
initial begin
    repeat(3) @(negedge clk);
    rst=0;
    for(cycle=0;cycle<500000;cycle=cycle+1) begin
        @(negedge clk);
        paused=cycle>=100000 && cycle<130000;
        mute=cycle>=200000 && cycle<210000;
        empty=cycle>=300000 && cycle<420000;
        #1;
        expected_read=tick & active & {6{!paused && !mute && !empty}};
        expected_valid=tick;
        @(posedge clk); #1;
        if(valid!==expected_valid || consumed!==expected_read)
            $fatal(1,"PCM timing/consume mismatch at cycle %d",cycle);
        for(i=0;i<6;i=i+1) begin
            if(expected_read[i] && {right_sample[i],left_sample[i]}!==32'h1234abcd)
                $fatal(1,"PCM data mismatch");
            if(expected_valid[i] && !expected_read[i] && {right_sample[i],left_sample[i]}!==0)
                $fatal(1,"mute/underflow silence mismatch");
        end
    end
    test_pass=1;
    $display("PASS reduced sample phase: 3 clocks x legacy/speed-enabled 1x; pause/mute/underflow; 500000 cycles each");
    $finish;
end
endmodule
