`timescale 1ns / 1ps
module tb_secondary_hdmi_symbol_buffer;
reg write_clk=0,read_clk=0,rst_n=0;
reg write_clock_running=1;
always #2.666667 if(write_clock_running) write_clk=!write_clk;
always #6.666667 read_clk=!read_clk;
reg input_valid=0,generate_input=0;
reg [29:0] input_symbols=0;
wire [29:0] output_symbols;
wire output_valid,fault;
secondary_hdmi_symbol_buffer dut(.*);
integer rate=400,accumulator=0,source_index=0,source_mode=0;
integer head=0,tail=0,compared=0,drops=0,repeats=0;
reg check_stream=1,test_pass=0;
reg [29:0] expected[0:200000];
function ordinary;
input [29:0] word;
begin ordinary=word[29:10]=={10'h354,10'h354} &&
    (word[9:0]==10'h354 || word[9:0]==10'h0ab || word[9:0]==10'h154 || word[9:0]==10'h2ab);
end endfunction
function [9:0] terc;
input [3:0] nibble;
begin case(nibble)
    0:terc=10'h29c;1:terc=10'h263;2:terc=10'h2e4;3:terc=10'h2e2;
    4:terc=10'h171;5:terc=10'h11e;6:terc=10'h18e;7:terc=10'h13c;
    8:terc=10'h2cc;9:terc=10'h139;10:terc=10'h19c;11:terc=10'h2c6;
    12:terc=10'h28e;13:terc=10'h271;14:terc=10'h163;15:terc=10'h2c3;
endcase end endfunction
function [29:0] source_word;
input integer n;
integer x;
begin
    x=(n-1024)%256;
    if(n<1024) source_word={10'h354,10'h354,10'h354};
    // Deliberately include RGB words aliasing TERC4/guards, then island
    // preamble, guards, consecutive packet-sized payloads and video preamble.
    // These are bit-exact transport vectors, not a decoded LPCM audio test.
    else if(source_mode==1 || x<64) source_word={10'h133,10'h133,terc(n[3:0])};
    else if(x<96) source_word={10'h354,10'h354,10'h0ab};
    else if(x<104) source_word={10'h0ab,10'h0ab,10'h354};
    else if(x<106 || (x>=170 && x<172)) source_word={10'h133,10'h133,10'h28e};
    else if(x<170) source_word={terc(n[7:4]),terc(n[3:0]),terc({1'b1,n[2:0]})};
    else if(x<246) source_word={10'h354,10'h354,10'h354};
    else if(x<254) source_word={10'h354,10'h0ab,10'h354};
    else source_word={10'h2cc,10'h133,10'h2cc};
end endfunction
always @(negedge write_clk) begin
    input_valid=0;
    if(rst_n && generate_input) begin
        accumulator=accumulator+rate;
        if(accumulator>=1000) begin
            accumulator=accumulator-1000;
            input_valid=1;input_symbols=source_word(source_index);
            source_index=source_index+1;
        end
    end
end
always @(posedge write_clk) if(rst_n && input_valid) begin
    if(dut.drop) begin
        drops=drops+1;
        if(!ordinary(input_symbols) || dut.write_run!=4)
            $fatal(1,"dropped a protected symbol or minimum control run");
    end
    if(check_stream && !ordinary(input_symbols)) begin
        if(tail>=200000) $fatal(1,"scoreboard limit");
        expected[tail]=input_symbols;tail=tail+1;
    end
end
reg valid_seen=0;
always @(posedge read_clk) begin
    if(rst_n && dut.repeat_control) begin
        repeats=repeats+1;
        if(!ordinary(dut.current_word)) $fatal(1,"repeated preamble/guard/video/packet");
    end
    #0.001;
    if(rst_n && check_stream) begin
        if(fault) $fatal(1,"unexpected buffer fault rate=%0d source=%0d head=%0d",rate,source_index,head);
        if(valid_seen && !output_valid) $fatal(1,"valid stream gap");
        if(output_valid) begin
            valid_seen=1;
            if(!ordinary(output_symbols)) begin
                if(head>=tail || output_symbols!==expected[head])
                    $fatal(1,"protected symbol changed/missing/repeated at %0d got=%h expected=%h",head,output_symbols,expected[head]);
                head=head+1;compared=compared+1;
            end
        end
    end
end
task restart;
begin
    rst_n=0;generate_input=0;input_valid=0;write_clock_running=1;
    #100;accumulator=0;source_index=0;head=0;tail=0;compared=0;
    drops=0;repeats=0;valid_seen=0;
    @(negedge read_clk);rst_n=1;generate_input=1;
end endtask
task stable_case;
input integer new_rate;
begin
    rate=new_rate;source_mode=0;check_stream=1;restart;
    repeat(250000) @(posedge write_clk);
    if(!output_valid || compared<20000) $fatal(1,"no continuous protected stream");
    if(rate>400 && drops==0) $fatal(1,"fast input did not exercise shortening");
    if(rate<400 && repeats==0) $fatal(1,"slow input did not exercise extension");
    $display("PASS rate=%0d per 1000 capture ticks: %0d exact protected words, drop=%0d repeat=%0d",rate,compared,drops,repeats);
end endtask
initial begin
    stable_case(400);stable_case(401);stable_case(399);
    // Stop a live source after enough active words to exhaust the FIFO.
    check_stream=0;source_mode=1;rate=400;restart;
    repeat(10000) @(posedge write_clk);
    generate_input=0;input_valid=0;
    repeat(1024) @(posedge read_clk);
    if(!fault || output_valid) $fatal(1,"underflow did not invalidate output");
    $display("PASS underflow is latched; corrupted stream is not marked ready");
    generate_input=1;
    repeat(1024) @(posedge read_clk);
    if(!fault || output_valid) $fatal(1,"late data revived a failed stream without reset");
    $display("PASS late source data cannot revive a faulted stream without reset");
    // Common asynchronous reset clears both domains even with source stopped.
    @(negedge write_clk);write_clock_running=0;rst_n=0;
    #20;if(output_valid || fault) $fatal(1,"stopped-low reset failed");
    restart;source_mode=0;check_stream=1;
    repeat(12000) @(posedge write_clk);
    if(!output_valid || compared<1000) $fatal(1,"reset/reconnect did not recover");
    check_stream=0;
    @(posedge write_clk);#0.01;write_clock_running=0;rst_n=0;
    #20;if(output_valid || fault) $fatal(1,"stopped-high reset failed");
    $display("PASS source stopped high/low: asynchronous invalidation and clean reconnect");
    // No safe control run: excessive rate mismatch must fail, not drop AV.
    source_mode=1;rate=500;restart;
    repeat(10000) @(posedge write_clk);
    repeat(10) @(posedge read_clk);
    if(!fault || output_valid) $fatal(1,"overflow did not invalidate output");
    if(!dut.write_fault) $fatal(1,"overflow not detected in write domain");
    $display("PASS uncorrectable overflow is latched without discarding AV payload");
    test_pass=1;$finish;
end
initial begin #10000000;$fatal(1,"symbol buffer timeout");end
endmodule
