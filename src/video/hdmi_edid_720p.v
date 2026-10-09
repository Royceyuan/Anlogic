`timescale 1ns / 1ps
`default_nettype none
// Read-only E-DDC: 720p60 RGB8 and 2-channel 48kHz/16-bit LPCM.
// No HDCP responder. SDA is open drain; never drive a logic one.
module hdmi_edid_720p (
    input wire clk, rst_n, enable, scl, sda,
    output reg sda_low
);
function [7:0] edid_byte;
    input [7:0] address;
    begin
        case(address)
            8'd1: edid_byte = 8'hff;
            8'd2: edid_byte = 8'hff;
            8'd3: edid_byte = 8'hff;
            8'd4: edid_byte = 8'hff;
            8'd5: edid_byte = 8'hff;
            8'd6: edid_byte = 8'hff;
            8'd8: edid_byte = 8'h05;
            8'd9: edid_byte = 8'hcc;
            8'd10: edid_byte = 8'h26;
            8'd11: edid_byte = 8'h20;
            8'd17: edid_byte = 8'h24;
            8'd18: edid_byte = 8'h01;
            8'd19: edid_byte = 8'h03;
            8'd20: edid_byte = 8'h80;
            8'd23: edid_byte = 8'h78;
            8'd24: edid_byte = 8'h0a;
            8'd25: edid_byte = 8'hee;
            8'd26: edid_byte = 8'h91;
            8'd27: edid_byte = 8'ha3;
            8'd28: edid_byte = 8'h54;
            8'd29: edid_byte = 8'h4c;
            8'd30: edid_byte = 8'h99;
            8'd31: edid_byte = 8'h26;
            8'd32: edid_byte = 8'h0f;
            8'd33: edid_byte = 8'h50;
            8'd34: edid_byte = 8'h54;
            8'd38: edid_byte = 8'h01;
            8'd39: edid_byte = 8'h01;
            8'd40: edid_byte = 8'h01;
            8'd41: edid_byte = 8'h01;
            8'd42: edid_byte = 8'h01;
            8'd43: edid_byte = 8'h01;
            8'd44: edid_byte = 8'h01;
            8'd45: edid_byte = 8'h01;
            8'd46: edid_byte = 8'h01;
            8'd47: edid_byte = 8'h01;
            8'd48: edid_byte = 8'h01;
            8'd49: edid_byte = 8'h01;
            8'd50: edid_byte = 8'h01;
            8'd51: edid_byte = 8'h01;
            8'd52: edid_byte = 8'h01;
            8'd53: edid_byte = 8'h01;
            8'd54: edid_byte = 8'h01;
            8'd55: edid_byte = 8'h1d;
            8'd57: edid_byte = 8'h72;
            8'd58: edid_byte = 8'h51;
            8'd59: edid_byte = 8'hd0;
            8'd60: edid_byte = 8'h1e;
            8'd61: edid_byte = 8'h20;
            8'd62: edid_byte = 8'h6e;
            8'd63: edid_byte = 8'h28;
            8'd64: edid_byte = 8'h55;
            8'd71: edid_byte = 8'h1e;
            8'd75: edid_byte = 8'hfc;
            8'd77: edid_byte = 8'h46;
            8'd78: edid_byte = 8'h50;
            8'd79: edid_byte = 8'h47;
            8'd80: edid_byte = 8'h41;
            8'd81: edid_byte = 8'h2d;
            8'd82: edid_byte = 8'h37;
            8'd83: edid_byte = 8'h32;
            8'd84: edid_byte = 8'h30;
            8'd85: edid_byte = 8'h50;
            8'd86: edid_byte = 8'h0a;
            8'd87: edid_byte = 8'h20;
            8'd88: edid_byte = 8'h20;
            8'd89: edid_byte = 8'h20;
            8'd93: edid_byte = 8'hff;
            8'd95: edid_byte = 8'h48;
            8'd96: edid_byte = 8'h44;
            8'd97: edid_byte = 8'h4d;
            8'd98: edid_byte = 8'h49;
            8'd99: edid_byte = 8'h2d;
            8'd100: edid_byte = 8'h52;
            8'd101: edid_byte = 8'h45;
            8'd102: edid_byte = 8'h4c;
            8'd103: edid_byte = 8'h41;
            8'd104: edid_byte = 8'h59;
            8'd105: edid_byte = 8'h0a;
            8'd106: edid_byte = 8'h20;
            8'd107: edid_byte = 8'h20;
            8'd111: edid_byte = 8'hfd;
            8'd113: edid_byte = 8'h3b;
            8'd114: edid_byte = 8'h3d;
            8'd115: edid_byte = 8'h2c;
            8'd116: edid_byte = 8'h2e;
            8'd117: edid_byte = 8'h08;
            8'd119: edid_byte = 8'h0a;
            8'd120: edid_byte = 8'h20;
            8'd121: edid_byte = 8'h20;
            8'd122: edid_byte = 8'h20;
            8'd123: edid_byte = 8'h20;
            8'd124: edid_byte = 8'h20;
            8'd125: edid_byte = 8'h20;
            8'd126: edid_byte = 8'h01;
            8'd127: edid_byte = 8'h38;
            8'd128: edid_byte = 8'h02;
            8'd129: edid_byte = 8'h03;
            8'd130: edid_byte = 8'h14;
            8'd131: edid_byte = 8'h41;
            8'd132: edid_byte = 8'h41;
            8'd133: edid_byte = 8'h84;
            8'd134: edid_byte = 8'h23;
            8'd135: edid_byte = 8'h09;
            8'd136: edid_byte = 8'h04;
            8'd137: edid_byte = 8'h01;
            8'd138: edid_byte = 8'h83;
            8'd139: edid_byte = 8'h01;
            8'd142: edid_byte = 8'h65;
            8'd143: edid_byte = 8'h03;
            8'd144: edid_byte = 8'h0c;
            8'd148: edid_byte = 8'h01;
            8'd149: edid_byte = 8'h1d;
            8'd151: edid_byte = 8'h72;
            8'd152: edid_byte = 8'h51;
            8'd153: edid_byte = 8'hd0;
            8'd154: edid_byte = 8'h1e;
            8'd155: edid_byte = 8'h20;
            8'd156: edid_byte = 8'h6e;
            8'd157: edid_byte = 8'h28;
            8'd158: edid_byte = 8'h55;
            8'd165: edid_byte = 8'h1e;
            8'd255: edid_byte = 8'hc0;
            default: edid_byte = 8'd0;
        endcase
    end
endfunction
localparam [3:0] IDLE=0, RX_ADDR=1, RX_POINTER=2, RX_SEGMENT=3,
    ACK_SETUP=4, ACK_RISE=5, ACK_FINISH=6, TX_DATA=7,
    TX_ACK_SETUP=8, TX_ACK_RISE=9, TX_ACK_FINISH=10, IGNORE=11;
reg [3:0] state, after_ack;
reg [2:0] bit_index;
reg [7:0] rx_shift, tx_shift, offset, segment;
reg ack_value, master_ack;
reg [2:0] scl_sync, sda_sync;
wire scl_rise = scl_sync[2:1] == 2'b01;
wire scl_fall = scl_sync[2:1] == 2'b10;
wire start_seen = &scl_sync[2:1] && sda_sync[2:1] == 2'b10;
wire stop_seen = &scl_sync[2:1] && sda_sync[2:1] == 2'b01;
wire [7:0] incoming = {rx_shift[6:0],sda_sync[2]};
wire [7:0] next_byte = edid_byte(offset);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin scl_sync<=3'b111; sda_sync<=3'b111; end
    else begin scl_sync<={scl_sync[1:0],scl}; sda_sync<={sda_sync[1:0],sda}; end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state<=IDLE; after_ack<=IGNORE; bit_index<=0; rx_shift<=0;
        tx_shift<=0; offset<=0; segment<=0;
        ack_value<=0; master_ack<=0; sda_low<=0;
    end else if (!enable) begin
        state<=IDLE; sda_low<=0; bit_index<=0;
    end else if (start_seen) begin
        state<=RX_ADDR; bit_index<=0; rx_shift<=0; sda_low<=0;
    end else if (stop_seen) begin state<=IDLE; sda_low<=0; end
    else case(state)
        RX_ADDR, RX_POINTER, RX_SEGMENT: if (scl_rise) begin
            rx_shift<=incoming;
            if (bit_index==7) begin
                bit_index<=0; state<=ACK_SETUP; ack_value<=1;
                if (state==RX_ADDR) begin
                    if (incoming[7:1]==7'h50 && segment==0)
                        after_ack<=incoming[0] ? TX_DATA : RX_POINTER;
                    else if (incoming==8'h60) after_ack<=RX_SEGMENT;
                    else begin ack_value<=0; after_ack<=IGNORE; end
                end else if (state==RX_POINTER) begin
                    offset<=incoming; after_ack<=IGNORE;
                end else begin
                    segment<=incoming; after_ack<=IGNORE;
                    // Segment >0 is remembered but never serves another block.
                end
            end else bit_index<=bit_index+1'b1;
        end
        ACK_SETUP: if (scl_fall) begin sda_low<=ack_value; state<=ACK_RISE; end
        ACK_RISE: if (scl_rise) state<=ACK_FINISH;
        ACK_FINISH: if (scl_fall) begin
            state<=after_ack; bit_index<=0; rx_shift<=0;
            sda_low<=0;
            if (after_ack==TX_DATA) begin tx_shift<=next_byte; sda_low<=!next_byte[7]; end
        end
        TX_DATA: begin
            if (scl_rise) begin
                if (bit_index==7) state<=TX_ACK_SETUP;
                else bit_index<=bit_index+1'b1;
            end
            if (scl_fall) begin tx_shift<={tx_shift[6:0],1'b0}; sda_low<=!tx_shift[6]; end
        end
        TX_ACK_SETUP: if (scl_fall) begin sda_low<=0; state<=TX_ACK_RISE; end
        TX_ACK_RISE: if (scl_rise) begin
            master_ack<=!sda_sync[2]; offset<=offset+1'b1; state<=TX_ACK_FINISH;
        end
        TX_ACK_FINISH: if (scl_fall) begin
            bit_index<=0;
            if (master_ack) begin tx_shift<=next_byte; sda_low<=!next_byte[7]; state<=TX_DATA; end
            else begin sda_low<=0; state<=IGNORE; end
        end
        default: sda_low<=0;
    endcase
end
endmodule
`default_nettype wire
