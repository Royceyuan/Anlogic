`timescale 1ns/1ps
`default_nettype none
// Byte transport reused from the main-board UART subtitle receiver/transmitter.
// 50 MHz / 434 = 115207 baud, 8N1. No subtitle storage or overlay is imported.
module secondary_uart_rx #(parameter integer BAUD_DIV=434)(
    input wire clk,rst_n,rxd, output reg [7:0] data, output reg valid
);
reg [1:0] state;
reg rxd_meta,rxd_sync,rxd_prev;
reg [12:0] count;
reg [2:0] bit_count;
reg [7:0] shift;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=0;rxd_meta<=1;rxd_sync<=1;rxd_prev<=1;
        count<=0;bit_count<=0;shift<=0;data<=0;valid<=0;
    end else begin
        rxd_meta<=rxd;rxd_sync<=rxd_meta;rxd_prev<=rxd_sync;valid<=0;
        case(state)
            0: if(rxd_prev&&!rxd_sync) begin state<=1;count<=0;end
            1: if(count==BAUD_DIV/2-1) begin
                count<=0;
                if(!rxd_sync) begin state<=2;bit_count<=0;end else state<=0;
            end else count<=count+1'b1;
            2: if(count==BAUD_DIV-1) begin
                count<=0;shift[bit_count]<=rxd_sync;
                if(bit_count==7) state<=3;else bit_count<=bit_count+1'b1;
            end else count<=count+1'b1;
            3: if(count==BAUD_DIV-1) begin
                count<=0;state<=0;
                if(rxd_sync) begin data<=shift;valid<=1;end
            end else count<=count+1'b1;
        endcase
    end
end
endmodule

module secondary_uart_tx #(parameter integer BAUD_DIV=434)(
    input wire clk,rst_n, input wire [7:0] data,input wire valid,
    output wire ready,output reg txd
);
reg busy;
reg [12:0] count;
reg [3:0] bit_count;
reg [7:0] data_q;
assign ready=!busy;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin busy<=0;count<=0;bit_count<=0;data_q<=0;txd<=1;end
    else if(!busy) begin
        txd<=1;
        if(valid) begin busy<=1;data_q<=data;count<=0;bit_count<=0;txd<=0;end
    end else if(count==BAUD_DIV-1) begin
        count<=0;
        if(bit_count<8) begin txd<=data_q[bit_count];bit_count<=bit_count+1'b1;end
        else if(bit_count==8) begin txd<=1;bit_count<=9;end
        else begin busy<=0;txd<=1;end
    end else count<=count+1'b1;
end
endmodule
`default_nettype wire
