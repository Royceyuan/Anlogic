`timescale 1ns/1ps
`default_nettype none
// Core-clock PCM quarantine. One bank may be provisional while the other is
// consumed. Only frame_done after SD CRC releases samples. The caller must
// observe frame_accept before starting a media frame, and stop sample_req on
// pause. HDMI sample timing/CDC and voice authorization are separate consumers.
module mvid_pcm_commit #(parameter integer SAMPLES_PER_FRAME=1600)(
    input wire clk,rst_n,clear,
    input wire frame_begin,frame_has_audio,frame_done,frame_abort,
    input wire pcm_valid,
    input wire [7:0] pcm_byte,
    output wire frame_accept,
    input wire sample_req,
    output reg sample_valid,sample_has_data,
    output wire [31:0] sample_data,
    output reg underflow,
    output reg [1:0] error
);
localparam integer INDEX_BITS=$clog2(SAMPLES_PER_FRAME);
localparam integer COUNT_BITS=$clog2(SAMPLES_PER_FRAME*4+1);
reg [31:0] samples[0:(2<<INDEX_BITS)-1];
reg [31:0] read_word;
reg [23:0] pack;
reg [COUNT_BITS-1:0] byte_count;
reg [INDEX_BITS-1:0] read_index;
reg [1:0] committed;
reg write_bank,read_bank,loading,has_audio;
assign frame_accept=!loading&&!committed[write_bank]&&error==0;
assign sample_data=sample_has_data?read_word:32'd0;
wire write_sample=loading&&has_audio&&pcm_valid&&byte_count<SAMPLES_PER_FRAME*4&&
    !clear&&!frame_abort&&error==0;
always @(posedge clk)begin
    if(write_sample&&byte_count[1:0]==3)
        samples[{write_bank,byte_count[INDEX_BITS+1:2]}]<={pcm_byte,pack};
    if(sample_req)read_word<=samples[{read_bank,read_index}];
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        pack<=0;byte_count<=0;read_index<=0;committed<=0;
        write_bank<=0;read_bank<=0;loading<=0;has_audio<=0;
        sample_valid<=0;sample_has_data<=0;underflow<=0;error<=0;
    end else begin
        sample_valid<=sample_req;sample_has_data<=sample_req&&committed[read_bank];
        if(sample_req)begin
            if(!committed[read_bank])underflow<=1;
            else if(read_index==SAMPLES_PER_FRAME-1)begin
                committed[read_bank]<=0;read_bank<=!read_bank;read_index<=0;
            end else read_index<=read_index+1'b1;
        end
        if(frame_begin)begin
            if(!frame_accept)error<=1;
            else begin loading<=1;has_audio<=frame_has_audio;byte_count<=0;pack<=0;end
        end
        if(pcm_valid&&loading)begin
            if(!has_audio||byte_count>=SAMPLES_PER_FRAME*4)begin error<=2;loading<=0;end
            else begin pack<={pcm_byte,pack[23:8]};byte_count<=byte_count+1'b1;end
        end
        if(frame_done&&loading)begin
            loading<=0;
            if(pcm_valid||byte_count!=(has_audio?SAMPLES_PER_FRAME*4:0))error<=2;
            else if(has_audio&&!frame_abort&&error==0)begin
                committed[write_bank]<=1;write_bank<=!write_bank;
            end
        end
        if(frame_abort)begin loading<=0;byte_count<=0;pack<=0;end
        if(clear)begin
            byte_count<=0;pack<=0;read_index<=0;committed<=0;
            write_bank<=0;read_bank<=0;loading<=0;has_audio<=0;
            sample_valid<=0;sample_has_data<=0;underflow<=0;error<=0;
        end
    end
end
endmodule
`default_nettype wire
