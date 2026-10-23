`timescale 1ns/1ps
`default_nettype none
// One outstanding request per client. Native multi-block reads are indivisible;
// an alternating grant bounds subtitle starvation without interleaving bytes.
module offline_sd_arbiter(
    input wire clk,rst_n,
    input wire video_start,
    input wire [31:0] video_lba,video_blocks,
    input wire subtitle_start,
    input wire [31:0] subtitle_lba,
    output wire video_valid,video_done,subtitle_valid,subtitle_done,
    output wire [7:0] client_data,
    output reg card_start,
    output reg [31:0] card_lba,card_blocks,
    input wire card_busy,card_done,card_valid,
    input wire [7:0] card_data,card_error,
    output wire busy
);
reg video_pending,subtitle_pending,subtitle_seen,owned,owner,last_owner;
reg [31:0] held_video_lba,held_video_blocks,held_subtitle_lba;
assign busy=owned||video_pending||subtitle_pending||card_start||card_busy||video_start||
    (subtitle_start&&!subtitle_seen);
assign client_data=card_data;
assign video_valid=owned&&!owner&&card_valid&&card_error==0;
assign subtitle_valid=owned&&owner&&card_valid&&card_error==0;
assign video_done=owned&&!owner&&card_done&&card_error==0;
assign subtitle_done=owned&&owner&&card_done&&card_error==0;
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        video_pending<=0;subtitle_pending<=0;subtitle_seen<=0;
        owned<=0;owner<=0;last_owner<=1;card_start<=0;card_lba<=0;card_blocks<=1;
        held_video_lba<=0;held_video_blocks<=0;held_subtitle_lba<=0;
    end else begin
        card_start<=0;
        if(!subtitle_start)subtitle_seen<=0;
        if(video_start)begin
            video_pending<=1;held_video_lba<=video_lba;held_video_blocks<=video_blocks;
        end
        if(subtitle_start&&!subtitle_seen)begin
            subtitle_pending<=1;subtitle_seen<=1;held_subtitle_lba<=subtitle_lba;
        end
        if(owned&&(card_done||card_error!=0))begin owned<=0;last_owner<=owner;end
        if(!owned&&!card_busy&&!card_start&&card_error==0)begin
            if(subtitle_pending&&(!video_pending||!last_owner))begin
                owner<=1;owned<=1;card_start<=1;subtitle_pending<=0;
                card_lba<=held_subtitle_lba;card_blocks<=1;
            end else if(video_pending)begin
                owner<=0;owned<=1;card_start<=1;video_pending<=0;
                card_lba<=held_video_lba;card_blocks<=held_video_blocks;
            end
        end
    end
end
endmodule
`default_nettype wire
