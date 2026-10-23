`timescale 1ns/1ps
`default_nettype none
// Telemetry anchors the same 48kHz sample timebase used by main subtitles.
// Between packets, only active automatic narration advances at main speed.
module secondary_offline_main_timeline #(parameter integer CLOCK_HZ=50_000_000,SAMPLE_HZ=48000)(
    input wire clk,rst,peer_alive,heartbeat_pulse,manual_mode,
    input wire [127:0] heartbeat_data,
    output reg [31:0] position
);
localparam BITS=$clog2(CLOCK_HZ);
reg [BITS-1:0] phase;
reg running;
reg [1:0] speed;
always @(posedge clk or posedge rst)begin
    if(rst)begin position<=0;phase<=0;running<=0;speed<=0;end
    else begin
        if(peer_alive&&running)begin
            if(phase>=CLOCK_HZ-SAMPLE_HZ)begin
                phase<=phase-(CLOCK_HZ-SAMPLE_HZ);position<=position+{30'd0,speed}+1'b1;
            end else phase<=phase+SAMPLE_HZ;
        end
        if(!peer_alive)running<=0;
        if(heartbeat_pulse&&peer_alive)begin
            position<=heartbeat_data[63:32];phase<=0;
            speed<=heartbeat_data[18:17]>2?0:heartbeat_data[18:17];
            running<=!manual_mode&&heartbeat_data[127:120]==2&&heartbeat_data[95:88]==0&&
                !heartbeat_data[70]&&!heartbeat_data[68]&&
                (heartbeat_data[103:96]==1||heartbeat_data[103:96]==3);
        end
    end
end
endmodule
`default_nettype wire
