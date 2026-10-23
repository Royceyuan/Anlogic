`timescale 1ns/1ps
`default_nettype none
// Core-clock file epochs. Never reset SD or the active HDMI scanner on a change.
module secondary_offline_file_control(
    input wire clk,rst_n,
    input wire [7:0] requested_id,
    input wire [31:0] requested_generation,
    input wire sd_busy,sd_start,frame_idle,movie_busy,file_ready,
    output wire stream_hold,
    output reg stream_clear,reader_rst_n,
    output reg [63:0] selected_stem,
    output reg [7:0] active_id,
    output reg [31:0] active_generation
);
localparam DRAIN=0,RESET=1,OPEN=2,PLAY=3;
reg [1:0] state;
reg [2:0] reset_cycles;
wire changed=requested_id!=active_id||requested_generation!=active_generation;
assign stream_hold=state!=PLAY||changed;
function [63:0] stem;
    input [7:0] id;
    begin case(id)
        0:stem="ART0    ";1:stem="ART1    ";2:stem="ART2    ";
        3:stem="ART3    ";4:stem="ART4    ";254:stem="EVAC    ";
        default:stem="GUIDE   ";
    endcase end
endfunction
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        state<=DRAIN;reset_cycles<=0;stream_clear<=0;reader_rst_n<=0;
        selected_stem<="GUIDE   ";active_id<=255;active_generation<=0;
    end else begin
        stream_clear<=0;
        case(state)
            DRAIN:if(!sd_busy&&!sd_start&&frame_idle&&!movie_busy)begin
                reader_rst_n<=0;stream_clear<=1;reset_cycles<=3;
                active_id<=requested_id;active_generation<=requested_generation;
                selected_stem<=stem(requested_id);state<=RESET;
            end
            RESET:if(reset_cycles!=0)reset_cycles<=reset_cycles-1'b1;
                else begin reader_rst_n<=1;state<=OPEN;end
            OPEN:if(changed)state<=DRAIN;else if(file_ready)state<=PLAY;
            PLAY:if(changed)state<=DRAIN;
        endcase
    end
end
endmodule
`default_nettype wire
