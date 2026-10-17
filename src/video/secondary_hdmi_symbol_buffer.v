`timescale 1ns / 1ps
`default_nettype none
// Capture-to-pixel symbol buffer for the common recovered-clock output.
// Preserve RGB, preambles, guards and complete encoded AV packets verbatim.
// Only a run of identical ordinary control words can absorb clock drift.
// ponytail: symbol-rate retiming, not frame genlock. The output selector must
// still preserve frame boundaries and revoke unauthorized PC video/audio.
// Raw PC ACR/PCM must keep the recovered PC clock. Do not use this buffer to
// change that clock without regenerating ACR and verifying audio rate/sync.
module secondary_hdmi_symbol_buffer (
    input wire rst_n,write_clk,read_clk,input_valid,
    input wire [29:0] input_symbols,
    output reg [29:0] output_symbols,
    output wire output_valid,
    output wire fault
);
localparam [8:0] LOW=128,HIGH=384,START=256;
function ordinary_control;
input [29:0] word;
begin
    ordinary_control=word[29:10]=={10'h354,10'h354} &&
        (word[9:0]==10'h354 || word[9:0]==10'h0ab ||
         word[9:0]==10'h154 || word[9:0]==10'h2ab);
end
endfunction
reg [1:0] write_reset,read_reset;
always @(posedge write_clk or negedge rst_n)
    if(!rst_n) write_reset<=3;else write_reset<={write_reset[0],1'b0};
always @(posedge read_clk or negedge rst_n)
    if(!rst_n) read_reset<=3;else read_reset<={read_reset[0],1'b0};
wire [8:0] write_count,read_count;
wire full,empty,fifo_valid;
wire [29:0] fifo_word;
reg write_fault,read_fault;
reg write_high;
reg [2:0] write_run,read_run;
reg draining,started;
reg write_fault_first,write_fault_second;
wire [1:0] write_fault_ff={write_fault_second,write_fault_first};
// First CDC stage on the distant read falling edge, then the ordinary rising
// edge. Keep the two-flop containment without a 0.665ns nominal setup edge.
always @(negedge read_clk or negedge rst_n)
    if(!rst_n) write_fault_first<=0;else write_fault_first<=write_fault;
reg input_valid_q,input_control_q;
// Keep the 30-bit comparison in two parallel halves at the capture clock.
// The final AND joins registered results, with the same symbol latency.
(* syn_preserve = 1 *) reg [1:0] input_same_parts;
wire input_same_q = &input_same_parts;
reg [29:0] input_word_q,last_input_word;
always @(posedge write_clk or negedge rst_n) begin
    if(!rst_n) begin
        input_valid_q<=0;input_control_q<=0;input_same_parts<=0;input_word_q<=0;last_input_word<=0;
    end else begin
        input_valid_q<=input_valid && !write_reset[1];
        if(input_valid) begin
            input_word_q<=input_symbols;input_control_q<=ordinary_control(input_symbols);
            input_same_parts<={input_symbols[29:15]==last_input_word[29:15],
                               input_symbols[14:0]==last_input_word[14:0]};
            last_input_word<=input_symbols;
        end
    end
end
// Retain at least four identical ordinary control words before shortening a
// run. Video/island preambles differ on green/red and can never be dropped.
// HIGH leaves 127 entries below full. Register the water mark so the FIFO
// address subtractor is not in the 187.5MHz RAM write-enable path; its one
// capture-clock delay can add at most one word before control shortening.
wire drop=input_valid_q && write_high && write_run==4 && input_control_q && input_same_q;
wire write_enable=input_valid_q && !drop && !write_reset[1] && !write_fault;
always @(posedge write_clk or negedge rst_n) begin
    if(!rst_n) write_high<=0;
    else write_high<=write_count>=HIGH;
end
always @(posedge write_clk or negedge rst_n) begin
    if(!rst_n) begin write_fault<=0;write_run<=0;end
    else if(!write_reset[1] && input_valid_q) begin
        if(write_enable && full) write_fault<=1;
        if(!drop) begin
            if(input_control_q) begin
                if(!input_same_q) write_run<=1;
                else if(write_run<4) write_run<=write_run+1'b1;
            end else write_run<=0;
        end
    end
end
// NOREG reads have one clock latency. Decide a hold from the word being
// emitted now, never blindly repeat an outstanding preamble/packet read.
wire [29:0] current_word=fifo_valid ? fifo_word : output_symbols;
wire repeat_safe=ordinary_control(current_word) && current_word==output_symbols && read_run>=3;
wire repeat_control=started && read_count<=LOW && repeat_safe;
wire read_enable=draining && !read_reset[1] && !read_fault &&
    !write_fault_ff[1] && !repeat_control;
rfifo_32_32_512 #(.DATA_WIDTH_W(30),.DATA_WIDTH_R(30),.NEGATIVE_READ_SYNC(1)) u_fifo(
    .rst(!rst_n),.clkw(write_clk),.clkr(read_clk),.we(write_enable),
    .di(input_word_q),.re(read_enable),.dout(fifo_word),.valid(fifo_valid),
    .full_flag(full),.empty_flag(empty),.afull(),.aempty(),
    .wrusedw(write_count),.rdusedw(read_count));
always @(posedge read_clk or negedge rst_n) begin
    if(!rst_n) begin
        write_fault_second<=0;read_fault<=0;draining<=0;started<=0;
        output_symbols<={10'h354,10'h354,10'h354};read_run<=0;
    end else begin
        write_fault_second<=write_fault_first;
        if(!read_reset[1]) begin
            if(read_count>=START) draining<=1;
            // The first read after a hold also has one clock of latency.
            // Bridge that single pipeline bubble with the same control word;
            // an actually empty FIFO or a protected word is not repeatable.
            if(started && !fifo_valid && (!repeat_safe || empty)) read_fault<=1;
            if(fifo_valid && !read_fault && !write_fault_ff[1]) begin
                output_symbols<=fifo_word;
                if(ordinary_control(fifo_word)) begin
                    if(fifo_word!=output_symbols) read_run<=1;
                    else if(read_run<4) read_run<=read_run+1'b1;
                    if(read_run>=3 && fifo_word==output_symbols) started<=1;
                end else read_run<=0;
            end
        end
    end
end
assign fault=read_fault || write_fault_ff[1];
assign output_valid=rst_n && started && !fault;
endmodule
`default_nettype wire
