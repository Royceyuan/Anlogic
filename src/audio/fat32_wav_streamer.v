`timescale 1ns / 1ps
`default_nettype none

// Read one fixed-format WAV from a FAT32 root directory.  The fixed names are
// AUDIO0.WAV through AUDIO4.WAV.  Canonical PCM16/48k/stereo remains
// mandatory so this small selector cannot destabilise the proven image path.
module fat32_wav_streamer #(
    parameter integer REUSE_GEOMETRY = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        restart,
    input  wire [2:0]  track_index,
    input  wire        sd_init_done,
    output reg         sd_sec_read,
    output reg [31:0]  sd_sec_read_addr,
    input  wire [7:0]  sd_sec_read_data,
    input  wire        sd_sec_read_data_valid,
    input  wire        sd_sec_read_end,

    input  wire        fifo_almost_full,
    output reg         fifo_wr_en,
    output reg [31:0]  fifo_wr_data,

    output reg         audio_ready,
    output reg         track_switch_ack,
    output reg [31:0]  total_pcm_frames,
    output reg         stream_done,
    output reg         format_error,
    output reg         file_error,
    output wire        fs_geometry_ready,
    output wire [7:0]  fs_sectors_per_cluster,
    output wire [31:0] fs_fat_start,
    output wire [31:0] fs_data_start,
    output wire [31:0] fs_root_cluster
);

localparam [4:0]
    S_WAIT_CARD  = 5'd0,
    S_REQ_MBR    = 5'd1,
    S_WAIT_MBR   = 5'd2,
    S_REQ_VBR    = 5'd3,
    S_WAIT_VBR   = 5'd4,
    S_REQ_ROOT   = 5'd5,
    S_WAIT_ROOT  = 5'd6,
    S_REQ_DATA   = 5'd7,
    S_WAIT_DATA  = 5'd8,
    S_REQ_FAT    = 5'd9,
    S_WAIT_FAT   = 5'd10,
    S_FAT_NEXT   = 5'd11,
    S_ERROR      = 5'd12,
    S_COMPLETE   = 5'd13;

reg [4:0] state;
reg [8:0] byte_index;
reg [31:0] partition_start;
reg [15:0] bytes_per_sector;
reg [7:0] sectors_per_cluster;
reg [15:0] reserved_sectors;
reg [7:0] num_fats;
reg [31:0] sectors_per_fat;
reg [31:0] root_cluster;
reg [31:0] fat_start;
reg [31:0] data_start;
reg [31:0] root_sector;
reg [7:0] root_sector_in_cluster;

reg entry_match;
reg entry_deleted;
reg [7:0] entry_attr;
reg [15:0] entry_cluster_hi;
reg [15:0] entry_cluster_lo;
reg [31:0] entry_file_size;
reg file_found;
reg [31:0] found_cluster;
reg [31:0] found_file_size;
reg [31:0] first_cluster;
reg [31:0] file_size;
reg [31:0] current_cluster;
reg [7:0] sector_in_cluster;
reg [31:0] file_bytes_seen;
reg [31:0] fat_next_cluster;
reg [8:0] fat_byte_offset;
reg fat_for_root;

reg header_ok;
reg header_complete;
reg [31:0] wav_data_bytes;
reg [1:0] pcm_byte_phase;
reg [7:0] left_lo;
reg [7:0] left_hi;
reg [7:0] right_lo;
reg [7:0] right_hi;
reg [2:0] active_track;

assign fs_geometry_ready       = (fat_start != 0) && (data_start != 0) &&
                                 (root_cluster >= 2);
assign fs_sectors_per_cluster  = sectors_per_cluster;
assign fs_fat_start            = fat_start;
assign fs_data_start           = data_start;
assign fs_root_cluster         = root_cluster;

wire [31:0] request_data_lba = cluster_lba(current_cluster, data_start,
    state == S_REQ_ROOT ? root_sector_in_cluster : sector_in_cluster);

function [31:0] cluster_lba;
    input [31:0] cluster;
    input [31:0] base;
    input [7:0] sector_offset;
    reg [31:0] cluster_offset;
    reg [2:0] shift;
    begin
        // FAT32 legal cluster sizes are powers of two.  Shifts avoid turning
        // this address calculation into several DSP blocks.
        case (sectors_per_cluster)
            8'd1:   shift = 3'd0;
            8'd2:   shift = 3'd1;
            8'd4:   shift = 3'd2;
            8'd8:   shift = 3'd3;
            8'd16:  shift = 3'd4;
            8'd32:  shift = 3'd5;
            8'd64:  shift = 3'd6;
            default: shift = 3'd7;
        endcase
        cluster_offset = (cluster - 32'd2) << shift;
        cluster_lba = base + cluster_offset + sector_offset;
    end
endfunction

function valid_sectors_per_cluster;
    input [7:0] value;
    begin
        case (value)
            8'd1, 8'd2, 8'd4, 8'd8, 8'd16, 8'd32, 8'd64, 8'd128:
                valid_sectors_per_cluster = 1'b1;
            default: valid_sectors_per_cluster = 1'b0;
        endcase
    end
endfunction

function header_byte_ok;
    input [5:0] index;
    input [7:0] value;
    begin
        header_byte_ok = 1'b1;
        case (index)
            6'd0:  header_byte_ok = (value == "R");
            6'd1:  header_byte_ok = (value == "I");
            6'd2:  header_byte_ok = (value == "F");
            6'd3:  header_byte_ok = (value == "F");
            6'd8:  header_byte_ok = (value == "W");
            6'd9:  header_byte_ok = (value == "A");
            6'd10: header_byte_ok = (value == "V");
            6'd11: header_byte_ok = (value == "E");
            6'd12: header_byte_ok = (value == "f");
            6'd13: header_byte_ok = (value == "m");
            6'd14: header_byte_ok = (value == "t");
            6'd15: header_byte_ok = (value == " ");
            6'd16: header_byte_ok = (value == 8'd16);
            6'd17,6'd18,6'd19: header_byte_ok = (value == 8'd0);
            6'd20: header_byte_ok = (value == 8'd1);
            6'd21: header_byte_ok = (value == 8'd0);
            6'd22: header_byte_ok = (value == 8'd2);
            6'd23: header_byte_ok = (value == 8'd0);
            6'd24: header_byte_ok = (value == 8'h80);
            6'd25: header_byte_ok = (value == 8'hBB);
            6'd26,6'd27: header_byte_ok = (value == 8'd0);
            6'd28: header_byte_ok = (value == 8'h00);
            6'd29: header_byte_ok = (value == 8'hEE);
            6'd30: header_byte_ok = (value == 8'h02);
            6'd31: header_byte_ok = (value == 8'd0);
            6'd32: header_byte_ok = (value == 8'd4);
            6'd33: header_byte_ok = (value == 8'd0);
            6'd34: header_byte_ok = (value == 8'd16);
            6'd35: header_byte_ok = (value == 8'd0);
            6'd36: header_byte_ok = (value == "d");
            6'd37: header_byte_ok = (value == "a");
            6'd38: header_byte_ok = (value == "t");
            6'd39: header_byte_ok = (value == "a");
            default: header_byte_ok = 1'b1;
        endcase
    end
endfunction

function root_name_byte_match;
    input [2:0] track;
    input [3:0] index;
    input [7:0] value;
    begin
        case (index)
            4'd0: root_name_byte_match = (value == "A");
            4'd1: root_name_byte_match = (value == "U");
            4'd2: root_name_byte_match = (value == "D");
            4'd3: root_name_byte_match = (value == "I");
            4'd4: root_name_byte_match = (value == "O");
            4'd5: root_name_byte_match = (value == (8'h30 + track));
            4'd6, 4'd7: root_name_byte_match = (value == " ");
            4'd8: root_name_byte_match = (value == "W");
            4'd9: root_name_byte_match = (value == "A");
            default: root_name_byte_match = (value == "V");
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state                  <= S_WAIT_CARD;
        sd_sec_read            <= 1'b0;
        sd_sec_read_addr       <= 32'd0;
        fifo_wr_en             <= 1'b0;
        fifo_wr_data           <= 32'd0;
        audio_ready            <= 1'b0;
        track_switch_ack       <= 1'b0;
        total_pcm_frames       <= 32'd0;
        stream_done            <= 1'b0;
        format_error           <= 1'b0;
        file_error             <= 1'b0;
        byte_index             <= 9'd0;
        partition_start        <= 32'd0;
        bytes_per_sector       <= 16'd0;
        sectors_per_cluster    <= 8'd0;
        reserved_sectors       <= 16'd0;
        num_fats               <= 8'd0;
        sectors_per_fat        <= 32'd0;
        root_cluster           <= 32'd0;
        fat_start              <= 32'd0;
        data_start             <= 32'd0;
        root_sector            <= 32'd0;
        root_sector_in_cluster <= 8'd0;
        entry_match            <= 1'b0;
        entry_deleted          <= 1'b0;
        entry_attr             <= 8'd0;
        entry_cluster_hi       <= 16'd0;
        entry_cluster_lo       <= 16'd0;
        entry_file_size        <= 32'd0;
        file_found             <= 1'b0;
        found_cluster          <= 32'd0;
        found_file_size        <= 32'd0;
        first_cluster          <= 32'd0;
        file_size              <= 32'd0;
        current_cluster        <= 32'd0;
        sector_in_cluster      <= 8'd0;
        file_bytes_seen        <= 32'd0;
        fat_next_cluster       <= 32'd0;
        fat_byte_offset        <= 9'd0;
        fat_for_root           <= 1'b0;
        header_ok              <= 1'b1;
        header_complete        <= 1'b0;
        wav_data_bytes         <= 32'd0;
        pcm_byte_phase         <= 2'd0;
        left_lo                <= 8'd0;
        left_hi                <= 8'd0;
        right_lo               <= 8'd0;
        right_hi               <= 8'd0;
        active_track           <= 3'd0;
    end else begin
        fifo_wr_en <= 1'b0;
        track_switch_ack <= 1'b0;
        // A full old-track FIFO cannot drain in overview/manual mode. At this
        // idle sector boundary reuse session restart; ACK clears the old FIFO.
        if (restart || !start || (state == S_REQ_DATA && track_index != active_track)) begin
            track_switch_ack <= start && !restart &&
                                state == S_REQ_DATA && track_index != active_track;
            state            <= S_WAIT_CARD;
            sd_sec_read      <= 1'b0;
            audio_ready      <= 1'b0;
            total_pcm_frames <= 32'd0;
            stream_done      <= 1'b0;
            format_error     <= 1'b0;
            file_error       <= 1'b0;
            pcm_byte_phase   <= 2'd0;
        end else case (state)
            S_WAIT_CARD: begin
                sd_sec_read <= 1'b0;
                if (start && sd_init_done) begin
                    active_track <= track_index;
                    // Keep shared FAT geometry stable while subtitles restart.
                    // A full KEY4 reset still invalidates it and rereads MBR/VBR.
                    if (REUSE_GEOMETRY && fs_geometry_ready) begin
                        current_cluster <= root_cluster;
                        root_sector_in_cluster <= 8'd0;
                        fat_for_root <= 1'b0;
                        state <= S_REQ_ROOT;
                    end else state <= S_REQ_MBR;
                end
            end

            S_REQ_MBR: begin
                byte_index       <= 9'd0;
                partition_start  <= 32'd0;
                sd_sec_read_addr <= 32'd0;
                sd_sec_read      <= 1'b1;
                state            <= S_WAIT_MBR;
            end
            S_WAIT_MBR: begin
                if (sd_sec_read_data_valid) begin
                    case (byte_index)
                        9'd454: partition_start[7:0]   <= sd_sec_read_data;
                        9'd455: partition_start[15:8]  <= sd_sec_read_data;
                        9'd456: partition_start[23:16] <= sd_sec_read_data;
                        9'd457: partition_start[31:24] <= sd_sec_read_data;
                    endcase
                    byte_index <= byte_index + 1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    state <= S_REQ_VBR;
                end
            end

            S_REQ_VBR: begin
                byte_index       <= 9'd0;
                bytes_per_sector <= 16'd0;
                sectors_per_cluster <= 8'd0;
                reserved_sectors <= 16'd0;
                num_fats         <= 8'd0;
                sectors_per_fat  <= 32'd0;
                root_cluster     <= 32'd0;
                sd_sec_read_addr <= partition_start;
                sd_sec_read      <= 1'b1;
                state            <= S_WAIT_VBR;
            end
            S_WAIT_VBR: begin
                if (sd_sec_read_data_valid) begin
                    case (byte_index)
                        9'd11: bytes_per_sector[7:0]  <= sd_sec_read_data;
                        9'd12: bytes_per_sector[15:8] <= sd_sec_read_data;
                        9'd13: sectors_per_cluster    <= sd_sec_read_data;
                        9'd14: reserved_sectors[7:0]  <= sd_sec_read_data;
                        9'd15: reserved_sectors[15:8] <= sd_sec_read_data;
                        9'd16: num_fats               <= sd_sec_read_data;
                        9'd36: sectors_per_fat[7:0]   <= sd_sec_read_data;
                        9'd37: sectors_per_fat[15:8]  <= sd_sec_read_data;
                        9'd38: sectors_per_fat[23:16] <= sd_sec_read_data;
                        9'd39: sectors_per_fat[31:24] <= sd_sec_read_data;
                        9'd44: root_cluster[7:0]      <= sd_sec_read_data;
                        9'd45: root_cluster[15:8]     <= sd_sec_read_data;
                        9'd46: root_cluster[23:16]    <= sd_sec_read_data;
                        9'd47: root_cluster[31:24]    <= sd_sec_read_data;
                    endcase
                    byte_index <= byte_index + 1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    // Canonical FAT32 values are mandatory for this reader.
                    if (bytes_per_sector != 16'd512 || !valid_sectors_per_cluster(sectors_per_cluster) ||
                        num_fats == 0 || sectors_per_fat == 0 || root_cluster < 2)
                        state <= S_ERROR;
                    else begin
                        fat_start         <= partition_start + reserved_sectors;
                        data_start        <= partition_start + reserved_sectors +
                                             (num_fats * sectors_per_fat);
                        current_cluster <= root_cluster;
                        root_sector_in_cluster <= 8'd0;
                        state <= S_REQ_ROOT;
                    end
                end
            end

            S_REQ_ROOT: begin
                byte_index       <= 9'd0;
                entry_match      <= 1'b1;
                entry_deleted    <= 1'b0;
                entry_attr       <= 8'd0;
                entry_cluster_hi <= 16'd0;
                entry_cluster_lo <= 16'd0;
                entry_file_size  <= 32'd0;
                file_found       <= 1'b0;
                sd_sec_read_addr <= request_data_lba;
                sd_sec_read      <= 1'b1;
                state            <= S_WAIT_ROOT;
            end
            S_WAIT_ROOT: begin
                if (sd_sec_read_data_valid) begin
                    case (byte_index[4:0])
                        5'd0:  begin
                            entry_match   <= root_name_byte_match(track_index, 4'd0,
                                                                  sd_sec_read_data);
                            entry_deleted <= (sd_sec_read_data == 8'he5);
                        end
                        5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7,5'd8,5'd9,5'd10:
                            if (!root_name_byte_match(track_index, byte_index[3:0],
                                                      sd_sec_read_data))
                                entry_match <= 1'b0;
                        5'd11: entry_attr <= sd_sec_read_data;
                        5'd20: entry_cluster_hi[7:0] <= sd_sec_read_data;
                        5'd21: entry_cluster_hi[15:8] <= sd_sec_read_data;
                        5'd26: entry_cluster_lo[7:0] <= sd_sec_read_data;
                        5'd27: entry_cluster_lo[15:8] <= sd_sec_read_data;
                        5'd28: entry_file_size[7:0] <= sd_sec_read_data;
                        5'd29: entry_file_size[15:8] <= sd_sec_read_data;
                        5'd30: entry_file_size[23:16] <= sd_sec_read_data;
                        5'd31: begin
                            entry_file_size[31:24] <= sd_sec_read_data;
                            if (entry_match && !entry_deleted &&
                                entry_attr != 8'h0f && !entry_attr[4] &&
                                {entry_cluster_hi, entry_cluster_lo} >= 2 &&
                                {sd_sec_read_data, entry_file_size[23:0]} >= 32'd48) begin
                                file_found <= 1'b1;
                                found_cluster <= {entry_cluster_hi,entry_cluster_lo};
                                found_file_size <= {sd_sec_read_data,entry_file_size[23:0]};
                            end
                        end
                    endcase
                    byte_index <= byte_index + 1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (track_index != active_track) begin
                        active_track <= track_index;
                        audio_ready <= 1'b0;
                        total_pcm_frames <= 32'd0;
                        stream_done <= 1'b0;
                        format_error <= 1'b0;
                        file_error <= 1'b0;
                        current_cluster <= root_cluster;
                        root_sector_in_cluster <= 8'd0;
                        track_switch_ack <= 1'b1;
                        state <= S_REQ_ROOT;
                    end else if (file_found) begin
                        fat_for_root      <= 1'b0;
                        first_cluster     <= found_cluster;
                        current_cluster   <= found_cluster;
                        file_size         <= found_file_size;
                        sector_in_cluster <= 8'd0;
                        file_bytes_seen   <= 32'd0;
                        header_ok         <= 1'b1;
                        header_complete   <= 1'b0;
                        pcm_byte_phase    <= 2'd0;
                        state             <= S_REQ_DATA;
                    end else if (root_sector_in_cluster + 1'b1 < sectors_per_cluster) begin
                        root_sector_in_cluster <= root_sector_in_cluster + 1'b1;
                        state <= S_REQ_ROOT;
                    end else begin
                        fat_byte_offset <= {current_cluster[6:0],2'b00};
                        fat_next_cluster <= 32'd0;
                        fat_for_root <= 1'b1;
                        state <= S_REQ_FAT;
                    end
                end
            end

            S_REQ_DATA: begin
                sd_sec_read <= 1'b0;
                if (!fifo_almost_full) begin
                    byte_index       <= 9'd0;
                    sd_sec_read_addr <= request_data_lba;
                    sd_sec_read      <= 1'b1;
                    state            <= S_WAIT_DATA;
                end
            end
            S_WAIT_DATA: begin
                if (sd_sec_read_data_valid) begin
                    if (file_bytes_seen < file_size) begin
                        if (file_bytes_seen < 32'd44) begin
                            if (!header_byte_ok(file_bytes_seen[5:0], sd_sec_read_data))
                                header_ok <= 1'b0;
                            case (file_bytes_seen)
                                32'd40: wav_data_bytes[7:0] <= sd_sec_read_data;
                                32'd41: wav_data_bytes[15:8] <= sd_sec_read_data;
                                32'd42: wav_data_bytes[23:16] <= sd_sec_read_data;
                                32'd43: begin
                                    wav_data_bytes[31:24] <= sd_sec_read_data;
                                    total_pcm_frames <= {2'b00, sd_sec_read_data,
                                                         wav_data_bytes[23:2]};
                                    header_complete <= 1'b1;
                                    if (!header_ok ||
                                        ({sd_sec_read_data,wav_data_bytes[23:0]} != file_size - 32'd44) ||
                                        (wav_data_bytes[1:0] != 2'b00))
                                        format_error <= 1'b1;
                                    else
                                        audio_ready <= 1'b1;
                                end
                            endcase
                        end else if (audio_ready) begin
                            case (pcm_byte_phase)
                                2'd0: left_lo  <= sd_sec_read_data;
                                2'd1: left_hi  <= sd_sec_read_data;
                                2'd2: right_lo <= sd_sec_read_data;
                                default: begin
                                    right_hi    <= sd_sec_read_data;
                                    fifo_wr_en  <= 1'b1;
                                    fifo_wr_data <= {{sd_sec_read_data,right_lo}, {left_hi,left_lo}};
                                end
                            endcase
                            pcm_byte_phase <= pcm_byte_phase + 1'b1;
                        end
                        file_bytes_seen <= file_bytes_seen + 1'b1;
                    end
                    byte_index <= byte_index + 1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (track_index != active_track) begin
                        active_track <= track_index;
                        audio_ready <= 1'b0;
                        total_pcm_frames <= 32'd0;
                        stream_done <= 1'b0;
                        format_error <= 1'b0;
                        file_error <= 1'b0;
                        current_cluster <= root_cluster;
                        root_sector_in_cluster <= 8'd0;
                        track_switch_ack <= 1'b1;
                        state <= S_REQ_ROOT;
                    end else if (format_error) begin
                        state <= S_ERROR;
                    end else if (file_bytes_seen >= file_size ||
                                 (sd_sec_read_data_valid && file_bytes_seen + 1'b1 >= file_size)) begin
                        stream_done <= 1'b1;
                        state       <= S_COMPLETE;
                    end else if (sector_in_cluster + 1'b1 < sectors_per_cluster) begin
                        sector_in_cluster <= sector_in_cluster + 1'b1;
                        state <= S_REQ_DATA;
                    end else begin
                        fat_byte_offset <= {current_cluster[6:0],2'b00};
                        fat_next_cluster <= 32'd0;
                        state <= S_REQ_FAT;
                    end
                end
            end

            S_REQ_FAT: begin
                byte_index       <= 9'd0;
                sd_sec_read_addr <= fat_start + (current_cluster >> 7);
                sd_sec_read      <= 1'b1;
                state            <= S_WAIT_FAT;
            end
            S_WAIT_FAT: begin
                if (sd_sec_read_data_valid) begin
                    if (byte_index == fat_byte_offset) begin
                        fat_next_cluster[7:0] <= sd_sec_read_data;
                    end else if (byte_index == fat_byte_offset + 1'b1) begin
                        fat_next_cluster[15:8] <= sd_sec_read_data;
                    end else if (byte_index == fat_byte_offset + 2'd2) begin
                        fat_next_cluster[23:16] <= sd_sec_read_data;
                    end else if (byte_index == fat_byte_offset + 2'd3) begin
                        fat_next_cluster[31:24] <= sd_sec_read_data;
                    end
                    byte_index <= byte_index + 1'b1;
                end
                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (track_index != active_track) begin
                        active_track <= track_index;
                        audio_ready <= 1'b0;
                        total_pcm_frames <= 32'd0;
                        stream_done <= 1'b0;
                        format_error <= 1'b0;
                        file_error <= 1'b0;
                        current_cluster <= root_cluster;
                        root_sector_in_cluster <= 8'd0;
                        track_switch_ack <= 1'b1;
                        state <= S_REQ_ROOT;
                    end else begin
                        state <= S_FAT_NEXT;
                    end
                end
            end
            S_FAT_NEXT: begin
                if (fat_next_cluster[27:0] >= 28'd2 &&
                    fat_next_cluster[27:0] < 28'hffffff8) begin
                    if (fat_for_root) begin
                        current_cluster <= {4'd0,fat_next_cluster[27:0]};
                        root_sector_in_cluster <= 8'd0;
                        fat_for_root <= 1'b0;
                        state <= S_REQ_ROOT;
                    end else begin
                        current_cluster   <= {4'd0,fat_next_cluster[27:0]};
                        sector_in_cluster <= 8'd0;
                        state             <= S_REQ_DATA;
                    end
                end else begin
                    state <= S_ERROR;
                end
            end

            S_COMPLETE: begin
                sd_sec_read <= 1'b0;
                if (track_index != active_track) begin
                    active_track <= track_index;
                    audio_ready <= 1'b0;
                    total_pcm_frames <= 32'd0;
                    stream_done <= 1'b0;
                    current_cluster <= root_cluster;
                    root_sector_in_cluster <= 8'd0;
                    track_switch_ack <= 1'b1;
                    state <= S_REQ_ROOT;
                end
            end

            default: begin
                sd_sec_read <= 1'b0;
                if (track_index != active_track && start && sd_init_done) begin
                    active_track <= track_index;
                    audio_ready <= 1'b0;
                    total_pcm_frames <= 32'd0;
                    stream_done <= 1'b0;
                    format_error <= 1'b0;
                    file_error <= 1'b0;
                    current_cluster <= root_cluster;
                    root_sector_in_cluster <= 8'd0;
                    track_switch_ack <= 1'b1;
                    state <= S_REQ_ROOT;
                end else begin
                    if (!format_error)
                        file_error <= 1'b1;
                    state <= S_ERROR;
                end
            end
        endcase
    end
end

endmodule

`default_nettype wire
