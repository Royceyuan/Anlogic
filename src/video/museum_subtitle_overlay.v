`timescale 1ns / 1ps
`default_nettype none

// Read SUB0.BIN..SUB4.BIN from FAT32 and present one pre-rendered 800x32
// subtitle cue at a time.  Only two bitmaps live on chip; the next cue is
// fetched while the current cue is displayed.
module museum_subtitle_overlay #(
    parameter integer VIDEO_W = 1280,
    parameter integer VIDEO_H = 720
)(
    input wire clk_50m, input wire rst_n_50m,
    input wire start, input wire restart,
    input wire lecture_active, input wire lecture_finished,
    input wire [2:0] track_index, input wire [31:0] audio_frame_index,
    input wire sd_init_done,
    input wire fs_geometry_ready, input wire [7:0] fs_sectors_per_cluster,
    input wire [31:0] fs_fat_start, input wire [31:0] fs_data_start,
    input wire [31:0] fs_root_cluster,
    output reg sd_sec_read, output reg [31:0] sd_sec_read_addr,
    input wire [7:0] sd_sec_read_data,
    input wire sd_sec_read_data_valid, input wire sd_sec_read_end,
    output reg subtitle_ready, output reg [31:0] subtitle_total_frames,
    output reg format_error, output reg file_error,
    input wire video_clk, input wire video_rst_n, input wire video_frame_tick,
    input wire hs_i, input wire vs_i, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    output reg hs_o, output reg vs_o, output reg de_o,
    output reg [10:0] x_o, output reg [9:0] y_o, output reg [23:0] rgb_o
);

localparam integer WIDTH = 800;
localparam integer HEIGHT = 32;
localparam integer BITMAP_BYTES = 3200;
localparam [9:0] Y_START = VIDEO_H - 44;
localparam [4:0] FADE_MAX = 5'd16;
localparam [4:0]
    S_WAIT_CARD = 5'd0,
    S_REQ_ROOT = 5'd5, S_WAIT_ROOT = 5'd6,
    S_REQ_DATA = 5'd7, S_WAIT_DATA = 5'd8,
    S_REQ_FAT = 5'd9, S_WAIT_FAT = 5'd10, S_FAT_NEXT = 5'd11,
    S_WAIT_CUE = 5'd12, S_WAIT_ACK = 5'd13,
    S_COMPLETE = 5'd14, S_ERROR = 5'd15;

reg [4:0] state;
reg [8:0] byte_index;
reg [7:0] root_sector_in_cluster;
reg entry_match, entry_deleted, file_found;
reg [7:0] entry_attr;
reg [15:0] entry_cluster_hi, entry_cluster_lo;
reg [31:0] entry_file_size, found_cluster, found_file_size;
reg [31:0] file_size, current_cluster, file_bytes_seen;
reg [7:0] sector_in_cluster;
reg [31:0] fat_next_cluster;
reg [8:0] fat_byte_offset;
reg fat_for_root;
reg [2:0] active_track;

reg header_ok, header_done;
reg [5:0] cue_count, cue_index;
reg [2:0] record_sector;
reg [11:0] payload_count;
reg [31:0] cue_start, cue_end, active_cue_end;
reg [9:0] cue_width, commit_width;
reg cue_ready, active_cue_valid, active_cue_is_last, pause_needs_fat;

reg bitmap_wr_en, write_bank;
reg [11:0] bitmap_wr_addr;
reg [7:0] bitmap_wr_data;
wire [7:0] bitmap0_q, bitmap1_q;
reg commit_toggle, commit_bank;
reg ack_sync1, ack_sync2, ack_seen;
reg commit_sync1, commit_sync2, commit_seen, active_bank, video_ack_toggle;
reg visible_sync1, visible_sync2;
reg [9:0] current_width;
reg [11:0] relative_x;
reg [1:0] fade_phase;
reg [4:0] fade_level;
reg video_has_cue, mapped_valid;
reg [11:0] bitmap_rd_addr;
reg hs_q,vs_q,de_q,mapped_q,bar_q,active_bank_q;
reg [10:0] x_q;
reg [9:0] y_q;
reg [23:0] rgb_q;
reg [2:0] pixel_q;

localparam [1:0] FADE_IDLE=2'd0, FADE_OUT=2'd1, FADE_IN=2'd2;

function [31:0] cluster_lba;
    input [31:0] cluster;
    input [31:0] base;
    input [7:0] sector_offset;
    reg [31:0] cluster_offset;
    begin
        case (fs_sectors_per_cluster)
            8'd1: cluster_offset = cluster - 32'd2;
            8'd2: cluster_offset = (cluster - 32'd2) << 1;
            8'd4: cluster_offset = (cluster - 32'd2) << 2;
            8'd8: cluster_offset = (cluster - 32'd2) << 3;
            8'd16: cluster_offset = (cluster - 32'd2) << 4;
            8'd32: cluster_offset = (cluster - 32'd2) << 5;
            8'd64: cluster_offset = (cluster - 32'd2) << 6;
            default: cluster_offset = (cluster - 32'd2) << 7;
        endcase
        cluster_lba = base + cluster_offset + sector_offset;
    end
endfunction

function root_name_byte_match;
    input [2:0] track;
    input [3:0] index;
    input [7:0] value;
    begin
        case (index)
            4'd0: root_name_byte_match = value == "S";
            4'd1: root_name_byte_match = value == "U";
            4'd2: root_name_byte_match = value == "B";
            4'd3: root_name_byte_match = value == 8'h30 + track;
            4'd4,4'd5,4'd6,4'd7: root_name_byte_match = value == " ";
            4'd8: root_name_byte_match = value == "B";
            4'd9: root_name_byte_match = value == "I";
            default: root_name_byte_match = value == "N";
        endcase
    end
endfunction

wire cue_visible_50m = start && lecture_active && !lecture_finished &&
                        active_cue_valid &&
                        (!active_cue_is_last || audio_frame_index < active_cue_end);

always @(posedge clk_50m or negedge rst_n_50m) begin
    if (!rst_n_50m) begin
        state<=S_WAIT_CARD; sd_sec_read<=0; sd_sec_read_addr<=0;
        byte_index<=0;
        root_sector_in_cluster<=0;
        entry_match<=0; entry_deleted<=0; entry_attr<=0;
        entry_cluster_hi<=0; entry_cluster_lo<=0; entry_file_size<=0;
        file_found<=0; found_cluster<=0; found_file_size<=0;
        file_size<=0; current_cluster<=0; file_bytes_seen<=0;
        sector_in_cluster<=0; fat_next_cluster<=0; fat_byte_offset<=0;
        fat_for_root<=0;
        active_track<=0; header_ok<=1; header_done<=0; cue_count<=0; cue_index<=0;
        record_sector<=0; payload_count<=0; cue_start<=0; cue_end<=0;
        active_cue_end<=0; cue_width<=0; commit_width<=0;
        cue_ready<=0; active_cue_valid<=0; active_cue_is_last<=0; pause_needs_fat<=0;
        bitmap_wr_en<=0; bitmap_wr_addr<=0; bitmap_wr_data<=0;
        write_bank<=1; commit_toggle<=0; commit_bank<=1;
        ack_sync1<=0; ack_sync2<=0; ack_seen<=0;
        subtitle_ready<=0; subtitle_total_frames<=0;
        format_error<=0; file_error<=0;
    end else begin
        bitmap_wr_en <= 1'b0;
        ack_sync1 <= video_ack_toggle;
        ack_sync2 <= ack_sync1;
        if (restart || !start) begin
            state<=S_WAIT_CARD; sd_sec_read<=0; subtitle_ready<=0;
            subtitle_total_frames<=0; format_error<=0; file_error<=0;
            cue_ready<=0; active_cue_valid<=0; cue_index<=0;
        end else if (track_index != active_track && !sd_sec_read &&
                     state != S_WAIT_CARD) begin
            active_track<=track_index; subtitle_ready<=0;
            subtitle_total_frames<=0; format_error<=0; file_error<=0;
            cue_ready<=0; active_cue_valid<=0; cue_index<=0;
            current_cluster<=fs_root_cluster; root_sector_in_cluster<=0;
            state<=fs_geometry_ready ? S_REQ_ROOT : S_WAIT_CARD;
        end else case (state)
            S_WAIT_CARD: begin
                sd_sec_read<=0;
                if (sd_init_done && fs_geometry_ready) begin
                    active_track<=track_index;
                    current_cluster<=fs_root_cluster;
                    root_sector_in_cluster<=0;
                    state<=S_REQ_ROOT;
                end
            end
            S_REQ_ROOT: begin
                byte_index<=0; entry_match<=1; entry_deleted<=0; entry_attr<=0;
                entry_cluster_hi<=0; entry_cluster_lo<=0; entry_file_size<=0;
                file_found<=0;
                sd_sec_read_addr<=cluster_lba(current_cluster,fs_data_start,
                                              root_sector_in_cluster);
                sd_sec_read<=1; state<=S_WAIT_ROOT;
            end
            S_WAIT_ROOT: begin
                if (sd_sec_read_data_valid) begin
                    case (byte_index[4:0])
                        5'd0: begin
                            entry_match<=root_name_byte_match(track_index,0,sd_sec_read_data);
                            entry_deleted<=sd_sec_read_data==8'he5;
                        end
                        5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7,5'd8,5'd9,5'd10:
                            if (!root_name_byte_match(track_index,byte_index[3:0],
                                                      sd_sec_read_data)) entry_match<=0;
                        5'd11: entry_attr<=sd_sec_read_data;
                        5'd20: entry_cluster_hi[7:0]<=sd_sec_read_data;
                        5'd21: entry_cluster_hi[15:8]<=sd_sec_read_data;
                        5'd26: entry_cluster_lo[7:0]<=sd_sec_read_data;
                        5'd27: entry_cluster_lo[15:8]<=sd_sec_read_data;
                        5'd28: entry_file_size[7:0]<=sd_sec_read_data;
                        5'd29: entry_file_size[15:8]<=sd_sec_read_data;
                        5'd30: entry_file_size[23:16]<=sd_sec_read_data;
                        5'd31: begin
                            entry_file_size[31:24]<=sd_sec_read_data;
                            if (entry_match && !entry_deleted && entry_attr!=8'h0f &&
                                !entry_attr[4] && {entry_cluster_hi,entry_cluster_lo}>=2 &&
                                {sd_sec_read_data,entry_file_size[23:0]}>=4096) begin
                                file_found<=1;
                                found_cluster<={entry_cluster_hi,entry_cluster_lo};
                                found_file_size<={sd_sec_read_data,entry_file_size[23:0]};
                            end
                        end
                    endcase
                    byte_index<=byte_index+1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read<=0;
                    if (file_found) begin
                        fat_for_root<=0;
                        current_cluster<=found_cluster; file_size<=found_file_size;
                        sector_in_cluster<=0; file_bytes_seen<=0; header_ok<=1;
                        header_done<=0;
                        cue_count<=0; cue_index<=0; record_sector<=0;
                        payload_count<=0; state<=S_REQ_DATA;
                    end else if (root_sector_in_cluster+1'b1<fs_sectors_per_cluster) begin
                        root_sector_in_cluster<=root_sector_in_cluster+1'b1;
                        state<=S_REQ_ROOT;
                    end else begin
                        fat_byte_offset<={current_cluster[6:0],2'b00};
                        fat_next_cluster<=0; fat_for_root<=1; state<=S_REQ_FAT;
                    end
                end
            end
            S_REQ_DATA: begin
                byte_index<=0;
                sd_sec_read_addr<=cluster_lba(current_cluster,fs_data_start,sector_in_cluster);
                sd_sec_read<=1; state<=S_WAIT_DATA;
            end
            S_WAIT_DATA: begin
                if (sd_sec_read_data_valid && file_bytes_seen<file_size) begin
                    if (!header_done) begin
                        case (byte_index)
                            9'd0: if (sd_sec_read_data!="M") header_ok<=0;
                            9'd1: if (sd_sec_read_data!="S") header_ok<=0;
                            9'd2: if (sd_sec_read_data!="U") header_ok<=0;
                            9'd3: if (sd_sec_read_data!="B") header_ok<=0;
                            9'd4: if (sd_sec_read_data!=1) header_ok<=0;
                            9'd5: if (sd_sec_read_data!=8'h20) header_ok<=0;
                            9'd6: if (sd_sec_read_data!=8'h03) header_ok<=0;
                            9'd7: if (sd_sec_read_data!=HEIGHT) header_ok<=0;
                            9'd8: if (sd_sec_read_data!=1) header_ok<=0;
                            9'd9: begin cue_count<=sd_sec_read_data[5:0];
                                if (sd_sec_read_data==0 || sd_sec_read_data>32) header_ok<=0;
                            end
                            9'd10: if (sd_sec_read_data!=8'h80) header_ok<=0;
                            9'd11: if (sd_sec_read_data!=8'h0c) header_ok<=0;
                            9'd12: if (sd_sec_read_data!=7) header_ok<=0;
                            9'd16: subtitle_total_frames[7:0]<=sd_sec_read_data;
                            9'd17: subtitle_total_frames[15:8]<=sd_sec_read_data;
                            9'd18: subtitle_total_frames[23:16]<=sd_sec_read_data;
                            9'd19: subtitle_total_frames[31:24]<=sd_sec_read_data;
                        endcase
                    end else begin
                        if (record_sector==0) begin
                            case (byte_index)
                                9'd0: cue_start[7:0]<=sd_sec_read_data;
                                9'd1: cue_start[15:8]<=sd_sec_read_data;
                                9'd2: cue_start[23:16]<=sd_sec_read_data;
                                9'd3: cue_start[31:24]<=sd_sec_read_data;
                                9'd4: cue_end[7:0]<=sd_sec_read_data;
                                9'd5: cue_end[15:8]<=sd_sec_read_data;
                                9'd6: cue_end[23:16]<=sd_sec_read_data;
                                9'd7: cue_end[31:24]<=sd_sec_read_data;
                                9'd8: cue_width[7:0]<=sd_sec_read_data;
                                9'd9: cue_width[9:8]<=sd_sec_read_data[1:0];
                            endcase
                        end
                        if (((record_sector==0 && byte_index>=16) || record_sector!=0) &&
                            payload_count<BITMAP_BYTES) begin
                            bitmap_wr_en<=1; bitmap_wr_addr<=payload_count;
                            bitmap_wr_data<=sd_sec_read_data;
                            payload_count<=payload_count+1'b1;
                        end
                    end
                    file_bytes_seen<=file_bytes_seen+1'b1;
                    byte_index<=byte_index+1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read<=0;
                    if (!header_done) begin
                        header_done<=1;
                        if (!header_ok) begin format_error<=1; state<=S_ERROR; end
                        else if (sector_in_cluster+1'b1<fs_sectors_per_cluster) begin
                            sector_in_cluster<=sector_in_cluster+1'b1; state<=S_REQ_DATA;
                        end else begin
                            fat_byte_offset<={current_cluster[6:0],2'b00};
                            fat_next_cluster<=0; state<=S_REQ_FAT;
                        end
                    end else if (record_sector==6) begin
                        if (payload_count!=BITMAP_BYTES || cue_start>=cue_end ||
                            cue_width==0 || cue_width>WIDTH) begin
                            format_error<=1; state<=S_ERROR;
                        end else begin
                            cue_ready<=1;
                            if (cue_index==0) subtitle_ready<=1;
                            if (sector_in_cluster+1'b1<fs_sectors_per_cluster) begin
                                sector_in_cluster<=sector_in_cluster+1'b1;
                                pause_needs_fat<=0;
                            end else pause_needs_fat<=1;
                            state<=S_WAIT_CUE;
                        end
                    end else begin
                        record_sector<=record_sector+1'b1;
                        if (sector_in_cluster+1'b1<fs_sectors_per_cluster) begin
                            sector_in_cluster<=sector_in_cluster+1'b1; state<=S_REQ_DATA;
                        end else begin
                            fat_byte_offset<={current_cluster[6:0],2'b00};
                            fat_next_cluster<=0; state<=S_REQ_FAT;
                        end
                    end
                end
            end
            S_REQ_FAT: begin
                byte_index<=0; sd_sec_read_addr<=fs_fat_start+(current_cluster>>7);
                sd_sec_read<=1; state<=S_WAIT_FAT;
            end
            S_WAIT_FAT: begin
                if (sd_sec_read_data_valid) begin
                    if (byte_index==fat_byte_offset) fat_next_cluster[7:0]<=sd_sec_read_data;
                    else if (byte_index==fat_byte_offset+1) fat_next_cluster[15:8]<=sd_sec_read_data;
                    else if (byte_index==fat_byte_offset+2) fat_next_cluster[23:16]<=sd_sec_read_data;
                    else if (byte_index==fat_byte_offset+3) fat_next_cluster[31:24]<=sd_sec_read_data;
                    byte_index<=byte_index+1'b1;
                end
                if (sd_sec_read_end) begin sd_sec_read<=0; state<=S_FAT_NEXT; end
            end
            S_FAT_NEXT: begin
                if (fat_next_cluster[27:0]>=2 && fat_next_cluster[27:0]<28'hffffff8) begin
                    if (fat_for_root) begin
                        current_cluster<={4'd0,fat_next_cluster[27:0]};
                        root_sector_in_cluster<=0; fat_for_root<=0; state<=S_REQ_ROOT;
                    end else begin
                        current_cluster<={4'd0,fat_next_cluster[27:0]};
                        sector_in_cluster<=0; state<=S_REQ_DATA;
                    end
                end else begin file_error<=1; state<=S_ERROR; end
            end
            S_WAIT_CUE: begin
                if (cue_ready && lecture_active && audio_frame_index>=cue_start &&
                    audio_frame_index<cue_end) begin
                    commit_bank<=write_bank; commit_toggle<=~commit_toggle;
                    commit_width<=cue_width;
                    active_cue_end<=cue_end;
                    active_cue_is_last<=cue_index+1'b1>=cue_count;
                    active_cue_valid<=1; cue_ready<=0; state<=S_WAIT_ACK;
                end else if (cue_ready && audio_frame_index>=cue_end) begin
                    // Late load: skip the expired cue without displaying it.
                    cue_ready<=0; active_cue_valid<=0; state<=S_WAIT_ACK;
                end
            end
            S_WAIT_ACK: begin
                if ((!active_cue_valid || ack_sync2!=ack_seen)) begin
                    ack_seen<=ack_sync2; write_bank<=~write_bank;
                    if (cue_index+1'b1>=cue_count) state<=S_COMPLETE;
                    else begin
                        cue_index<=cue_index+1'b1; record_sector<=0; payload_count<=0;
                        cue_start<=0; cue_end<=0; cue_width<=0;
                        if (pause_needs_fat) begin
                            fat_byte_offset<={current_cluster[6:0],2'b00};
                            fat_next_cluster<=0; state<=S_REQ_FAT;
                        end else state<=S_REQ_DATA;
                    end
                end
            end
            S_COMPLETE: begin sd_sec_read<=0; end
            default: begin sd_sec_read<=0; file_error<=file_error|!format_error; end
        endcase
    end
end

subtitle_bitmap_ram #(.ADDR_WIDTH(12),.DEPTH(4096),.REGISTER_READ(0)) u_bitmap0 (
    .wr_clk(clk_50m),.wr_en(bitmap_wr_en&&!write_bank),.wr_addr(bitmap_wr_addr),
    .wr_data(bitmap_wr_data),.rd_clk(video_clk),.rd_addr(bitmap_rd_addr),.rd_data(bitmap0_q));
subtitle_bitmap_ram #(.ADDR_WIDTH(12),.DEPTH(4096),.REGISTER_READ(0)) u_bitmap1 (
    .wr_clk(clk_50m),.wr_en(bitmap_wr_en&&write_bank),.wr_addr(bitmap_wr_addr),
    .wr_data(bitmap_wr_data),.rd_clk(video_clk),.rd_addr(bitmap_rd_addr),.rd_data(bitmap1_q));

wire [11:0] current_center = (VIDEO_W-current_width) >> 1;
wire [7:0] bitmap_q = active_bank_q ? bitmap1_q : bitmap0_q;
reg [23:0] faded_text_rgb;

always @(*) begin
    relative_x = x_i>=current_center ? x_i-current_center : 0;
    mapped_valid = de_i && visible_sync2 && video_has_cue &&
                   y_i>=Y_START && y_i<Y_START+HEIGHT &&
                   x_i>=current_center && relative_x<current_width;
    bitmap_rd_addr = ((y_i-Y_START)<<6)+((y_i-Y_START)<<5)+
                     ((y_i-Y_START)<<2)+relative_x[9:3];
    case (fade_level[4:1])
        4'd0: faded_text_rgb = 24'h101820;
        4'd1: faded_text_rgb = 24'h2E332F;
        4'd2: faded_text_rgb = 24'h4C4E49;
        4'd3: faded_text_rgb = 24'h6A6962;
        4'd4: faded_text_rgb = 24'h888474;
        4'd5: faded_text_rgb = 24'hA69F8D;
        4'd6: faded_text_rgb = 24'hC4BAA6;
        4'd7: faded_text_rgb = 24'hE2D5BD;
        default: faded_text_rgb = 24'hFFF1C7;
    endcase
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        commit_sync1<=0; commit_sync2<=0; commit_seen<=0; active_bank<=0;
        video_ack_toggle<=0; visible_sync1<=0; visible_sync2<=0;
        current_width<=0; fade_level<=0;
        video_has_cue<=0; fade_phase<=FADE_IDLE;
        hs_q<=1;vs_q<=1;de_q<=0;mapped_q<=0;bar_q<=0;active_bank_q<=0;
        x_q<=0;y_q<=0;rgb_q<=0;pixel_q<=0;
        hs_o<=1;vs_o<=1;de_o<=0;x_o<=0;y_o<=0;rgb_o<=0;
    end else begin
        commit_sync1<=commit_toggle; commit_sync2<=commit_sync1;
        visible_sync1<=cue_visible_50m; visible_sync2<=visible_sync1;
        if (video_frame_tick) begin
            if (commit_sync2!=commit_seen) begin
                commit_seen<=commit_sync2;
                if (video_has_cue&&visible_sync2) begin
                    fade_phase<=FADE_OUT;
                end else begin
                    active_bank<=commit_bank; current_width<=commit_width;
                    fade_level<=0; video_has_cue<=1; fade_phase<=FADE_IN;
                end
            end else if (fade_phase==FADE_OUT) begin
                if (fade_level==0) begin
                    active_bank<=commit_bank; current_width<=commit_width;
                    fade_phase<=FADE_IN;
                end else fade_level<=fade_level-1'b1;
            end else if (fade_phase==FADE_IN) begin
                if (fade_level==FADE_MAX) begin
                    fade_phase<=FADE_IDLE;
                    video_ack_toggle<=~video_ack_toggle;
                end else fade_level<=fade_level+1'b1;
            end
        end
        hs_o<=hs_q;vs_o<=vs_q;de_o<=de_q;x_o<=x_q;y_o<=y_q;
        if (!de_q) rgb_o<=24'h000000;
        else if (mapped_q && bitmap_q[7-pixel_q]) rgb_o<=faded_text_rgb;
        else if (bar_q) rgb_o<=24'h101820;
        else rgb_o<=rgb_q;
        hs_q<=hs_i;vs_q<=vs_i;de_q<=de_i;x_q<=x_i;y_q<=y_i;rgb_q<=rgb_i;
        pixel_q<=relative_x[2:0]; mapped_q<=mapped_valid; active_bank_q<=active_bank;
        bar_q<=de_i&&visible_sync2&&video_has_cue&&
               y_i>=Y_START&&y_i<Y_START+HEIGHT;
    end
end

endmodule

`default_nettype wire
