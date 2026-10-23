`timescale 1ns/1ps
`default_nettype none
// Native SD command/response PHY. tick_rise/fall describe the external clock.
module sd_native_command #(
    parameter integer RESPONSE_TIMEOUT = 512
)(
    input wire clk,rst_n,tick_rise,tick_fall,start,
    input wire [5:0] command,
    input wire [31:0] argument,
    input wire [7:0] response_bits,
    input wire check_crc,cmd_i,
    output reg cmd_o,cmd_oe,busy,done,
    output reg [2:0] error,
    output reg [135:0] response
);
function [6:0] command_crc;
    input [39:0] body;
    reg [6:0] c;
    integer i;
    begin
        c=0;
        for(i=39;i>=0;i=i-1) c={c[5:0],1'b0}^((c[6]^body[i])?7'h09:7'h00);
        command_crc=c;
    end
endfunction
localparam IDLE=0,TX=1,RELEASE=2,WAIT_START=3,RX=4,CHECK=5,GAP=6;
reg [2:0] state;
reg [47:0] shift;
reg [7:0] count,length;
reg verify_crc;
reg [6:0] received_crc;
reg [15:0] wait_cycles;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=IDLE;cmd_o<=1;cmd_oe<=0;busy<=0;done<=0;error<=0;
        response<=0;shift<=0;count<=0;length<=0;verify_crc<=0;wait_cycles<=0;received_crc<=0;
    end else begin
        done<=0;
        case(state)
            IDLE: if(start) begin
                shift<={2'b01,command,argument,command_crc({2'b01,command,argument}),1'b1};
                count<=48;length<=response_bits;verify_crc<=check_crc;
                busy<=1;error<=0;response<=0;received_crc<=0;wait_cycles<=0;state<=GAP;
            end
            // Leave eight complete SD clocks before each command, including
            // after a response or CMD0. Core-clock latency is not an SD gap.
            GAP: if(tick_rise) begin
                if(wait_cycles==7) state<=TX;
                else wait_cycles<=wait_cycles+1'b1;
            end
            TX: if(tick_fall) begin
                cmd_oe<=1;cmd_o<=shift[47];shift<={shift[46:0],1'b1};
                count<=count-1'b1;
                if(count==1) state<=RELEASE;
            end
            RELEASE: if(tick_fall) begin
                cmd_oe<=0;cmd_o<=1;wait_cycles<=0;
                if(length==0) begin state<=IDLE;busy<=0;done<=1;end
                else state<=WAIT_START;
            end
            WAIT_START: if(tick_rise) begin
                if(!cmd_i) begin response<=0;count<=length-1'b1;state<=RX;end
                else if(wait_cycles==RESPONSE_TIMEOUT-1) begin
                    error<=1;state<=IDLE;busy<=0;done<=1;
                end else wait_cycles<=wait_cycles+1'b1;
            end
            RX: if(tick_rise) begin
                response<={response[134:0],cmd_i};count<=count-1'b1;
                if(count>8 && (length!=136 || count<=128))
                    received_crc<={received_crc[5:0],1'b0}^((received_crc[6]^cmd_i)?7'h09:7'h00);
                if(count==1) state<=CHECK;
            end
            CHECK: begin
                if(!response[0] || (length==48 && response[46])) error<=2;
                else if(verify_crc && received_crc!=response[7:1]) error<=3;
                state<=IDLE;busy<=0;done<=1;
            end
            default:state<=IDLE;
        endcase
    end
end
endmodule
`default_nettype wire
