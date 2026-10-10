`timescale 1ns/1ps
`default_nettype none
// Request: A5 5A command sequence CRC8. Reply: 5A A5 sequence flags CRC8.
// CRC8/SMBUS: poly 07, init 00, no reflection/xorout, covers first four bytes.
// Commands: 1=start, 2=stop, 3=query, 4=keepalive. One outstanding PC request.
// Flags: bit0=input ready, bit1=selected, bit2=muted, bit3=authorized, bit7=reject.
module secondary_video_uart_control #(
    parameter integer BAUD_DIV=434,CLOCKS_PER_MS=50000,WATCHDOG_MS=3000
)(
    input wire clk,rst_n,uart_rxd,input_ready,external_selected,output_muted,
    output wire uart_txd,output reg play_enabled
);
function [7:0] crc8;
input [7:0] crc,value;
reg [7:0] work;
integer i;
begin
    work=crc^value;
    for(i=0;i<8;i=i+1) work=work[7] ? (work<<1)^8'h07 : work<<1;
    crc8=work;
end
endfunction
wire [7:0] rx_data;
wire rx_valid,tx_ready;
reg [7:0] tx_data;
reg tx_valid;
secondary_uart_rx #(.BAUD_DIV(BAUD_DIV)) u_rx(
    .clk(clk),.rst_n(rst_n),.rxd(uart_rxd),.data(rx_data),.valid(rx_valid));
secondary_uart_tx #(.BAUD_DIV(BAUD_DIV)) u_tx(
    .clk(clk),.rst_n(rst_n),.data(tx_data),.valid(tx_valid),.ready(tx_ready),.txd(uart_txd));
reg [15:0] ms_cycles;
wire ms_tick=ms_cycles==CLOCKS_PER_MS-1;
reg [11:0] lease_ms;
reg [3:0] rx_age_ms;
reg [2:0] rx_state,tx_index;
reg [7:0] command,sequence,rx_crc,tx_crc,reply_sequence,ack_sequence,ack_flags;
reg reply_pending,reply_rejected,tx_active;
wire [7:0] flags={reply_rejected,3'b000,play_enabled,output_muted,external_selected,input_ready};
reg [7:0] next_tx_data;
always @* case(tx_index)
    0:next_tx_data=8'h5a;
    1:next_tx_data=8'ha5;
    2:next_tx_data=ack_sequence;
    3:next_tx_data=ack_flags;
    default:next_tx_data=tx_crc;
endcase
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ms_cycles<=0;lease_ms<=0;play_enabled<=0;rx_age_ms<=0;
        rx_state<=0;command<=0;sequence<=0;rx_crc<=0;
        reply_pending<=0;reply_rejected<=0;reply_sequence<=0;
        tx_active<=0;tx_index<=0;tx_crc<=0;ack_sequence<=0;ack_flags<=0;
        tx_data<=0;tx_valid<=0;
    end else begin
        tx_valid<=0;
        if(ms_tick) ms_cycles<=0;else ms_cycles<=ms_cycles+1'b1;
        if(!input_ready) play_enabled<=0;
        if(ms_tick) begin
            if(play_enabled) begin
                if(lease_ms==WATCHDOG_MS-1) begin play_enabled<=0;lease_ms<=0;end
                else lease_ms<=lease_ms+1'b1;
            end else lease_ms<=0;
            if(rx_state!=0) begin
                if(rx_age_ms==9) begin rx_state<=0;rx_age_ms<=0;end
                else rx_age_ms<=rx_age_ms+1'b1;
            end
        end
        // A pending reply may be replaced by the newest request, but STOP is
        // applied even during reply transmission. The PC serializes requests.
        if(reply_pending&&!tx_active&&tx_ready&&!tx_valid) begin
            ack_sequence<=reply_sequence;ack_flags<=flags;
            tx_index<=0;tx_crc<=0;tx_active<=1;reply_pending<=0;
        end else if(tx_active&&tx_ready&&!tx_valid) begin
            tx_data<=next_tx_data;tx_valid<=1;
            if(tx_index==4) tx_active<=0;
            else begin tx_crc<=crc8(tx_crc,next_tx_data);tx_index<=tx_index+1'b1;end
        end
        if(rx_valid) begin
            rx_age_ms<=0;
            case(rx_state)
                0: if(rx_data==8'ha5) begin rx_state<=1;rx_crc<=crc8(0,8'ha5);end
                1: if(rx_data==8'h5a) begin rx_state<=2;rx_crc<=crc8(rx_crc,rx_data);end
                   else if(rx_data!=8'ha5) rx_state<=0;
                2: begin command<=rx_data;rx_crc<=crc8(rx_crc,rx_data);rx_state<=3;end
                3: begin sequence<=rx_data;rx_crc<=crc8(rx_crc,rx_data);rx_state<=4;end
                4: begin
                    rx_state<=0;
                    if(rx_data==rx_crc) begin
                        reply_sequence<=sequence;reply_pending<=1;reply_rejected<=0;
                        case(command)
                            1: if(input_ready) begin play_enabled<=1;lease_ms<=0;end
                               else reply_rejected<=1;
                            2: begin play_enabled<=0;lease_ms<=0;end
                            3: ;
                            4: if(play_enabled) lease_ms<=0;
                            default:reply_rejected<=1;
                        endcase
                    end else if(rx_data==8'ha5) begin rx_state<=1;rx_crc<=crc8(0,8'ha5);end
                end
                default:rx_state<=0;
            endcase
        end
    end
end
endmodule
`default_nettype wire
