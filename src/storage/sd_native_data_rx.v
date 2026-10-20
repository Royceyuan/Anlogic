`timescale 1ns/1ps
`default_nettype none
// Four-bit read-only data PHY, with an independent CRC16 for each DAT lane.
// Consumers stage data until block_done; invalid blocks must never be published.
module sd_native_data_rx #(
    parameter integer TIMEOUT_CYCLES=10_000_000
)(
    input wire clk,rst_n,tick_rise,start,cancel,continuous,
    input wire [10:0] block_bytes,
    input wire [3:0] dat,
    output reg busy,valid,block_done,
    output reg [7:0] data,
    output reg [9:0] byte_index,
    output reg [2:0] error
);
localparam IDLE=0,WAIT_START=1,PAYLOAD=2,CRC=3,END_BIT=4;
reg [2:0] state;
reg [10:0] length;
reg [3:0] high_nibble,crc_bit;
reg nibble;
reg [15:0] crc0,crc1,crc2,crc3,received0,received1,received2,received3;
reg [23:0] timeout;
function [15:0] crc_next;
    input [15:0] c;
    input bit_in;
    begin crc_next={c[14:0],1'b0}^((c[15]^bit_in)?16'h1021:16'h0000);end
endfunction
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=IDLE;busy<=0;valid<=0;block_done<=0;data<=0;byte_index<=0;
        length<=0;high_nibble<=0;crc_bit<=0;nibble<=0;error<=0;timeout<=0;
        crc0<=0;crc1<=0;crc2<=0;crc3<=0;
        received0<=0;received1<=0;received2<=0;received3<=0;
    end else begin
        valid<=0;block_done<=0;
        if(cancel) begin state<=IDLE;busy<=0;end
        else if(start) begin state<=WAIT_START;busy<=1;length<=block_bytes;error<=0;timeout<=0;end
        else if(busy && timeout==TIMEOUT_CYCLES-1) begin
            error<=1;block_done<=1;busy<=0;state<=IDLE;
        end else begin
            if(busy) timeout<=timeout+1'b1;
            case(state)
                WAIT_START: if(tick_rise && dat==0) begin
                    state<=PAYLOAD;nibble<=0;byte_index<=0;timeout<=0;
                    crc0<=0;crc1<=0;crc2<=0;crc3<=0;
                    received0<=0;received1<=0;received2<=0;received3<=0;
                end
                PAYLOAD: if(tick_rise) begin
                    crc0<=crc_next(crc0,dat[0]);crc1<=crc_next(crc1,dat[1]);
                    crc2<=crc_next(crc2,dat[2]);crc3<=crc_next(crc3,dat[3]);
                    nibble<=~nibble;
                    if(!nibble) high_nibble<=dat;
                    else begin
                        data<={high_nibble,dat};valid<=1;
                        if(byte_index==length-1) begin state<=CRC;crc_bit<=0;end
                    end
                end
                CRC: if(tick_rise) begin
                    received0<={received0[14:0],dat[0]};received1<={received1[14:0],dat[1]};
                    received2<={received2[14:0],dat[2]};received3<={received3[14:0],dat[3]};
                    crc_bit<=crc_bit+1'b1;
                    if(crc_bit==15) state<=END_BIT;
                end
                END_BIT: if(tick_rise) begin
                    block_done<=1;timeout<=0;
                    if(dat!=15) begin error<=2;busy<=0;state<=IDLE;end
                    else if(received0!=crc0||received1!=crc1||received2!=crc2||received3!=crc3) begin
                        error<=3;busy<=0;state<=IDLE;
                    end else if(continuous) state<=WAIT_START;
                    else begin state<=IDLE;busy<=0;end
                end
                default:;
            endcase
            // Keep the index aligned with the registered byte/valid outputs.
            if(valid && state==PAYLOAD) byte_index<=byte_index+1'b1;
        end
    end
end
endmodule
`default_nettype wire
