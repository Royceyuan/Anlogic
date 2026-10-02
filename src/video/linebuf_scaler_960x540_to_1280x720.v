`timescale 1ns / 1ps
`default_nettype none

// Streams one RGB565 frame from the SDRAM read FIFO into three rotating line
// buffers and produces a 1280x720 raster. The production ratio is 960:1280
// and 540:720, so both mappings reduce to 3/4 without pixel-path division.
module linebuf_scaler_960x540_to_1280x720 #(
    parameter integer SRC_W = 960,
    parameter integer SRC_H = 540,
    parameter integer DST_W = 1280,
    parameter integer DST_H = 720,
    parameter integer LINEBUF_REGISTER_READ = 0,
    parameter integer LINEBUF_NOREG_SYNC_READ = 0,
    parameter integer FIFO_RESPONSE_REGISTER = 0,
    parameter integer ENABLE_PAN = 0
) (
    input  wire        clk,
    input  wire        rst_n,

    // Start one sequential source-frame transaction during video blanking.
    input  wire        source_start,
    input  wire        zoom_2x,
    input  wire signed [15:0] pan_x,
    input  wire signed [15:0] pan_y,
    input  wire        museum_recenter_active,
    input  wire        museum_recenter_closing,
    input  wire [7:0]  museum_recenter_progress,
    input  wire [2:0]  museum_recenter_origin,
    input  wire [20:0] source_base_addr,
    output reg         source_read_req,
    input  wire        source_read_ack,
    output wire [20:0] source_read_base_addr,
    output wire [20:0] source_read_len,
    input  wire        source_fifo_empty,
    input  wire        source_fifo_valid,
    output wire        source_read_en,
    input  wire [31:0] source_read_data,

    input  wire        video_de,
    input  wire [10:0] video_x,
    input  wire [9:0]  video_y,
    output wire [15:0] pixel565,
    output wire        frame_ready,
    output reg         source_frame_done,
    output reg         underflow
);

localparam integer WORDS_PER_ROW = SRC_W / 2;
localparam integer FRAME_WORDS  = WORDS_PER_ROW * SRC_H;
localparam integer ZOOM_ROW_START = SRC_H / 4;
localparam integer ZOOM_FRAME_WORDS = WORDS_PER_ROW * (SRC_H / 2);
localparam integer ROW_BITS     = (SRC_H <= 1) ? 1 : $clog2(SRC_H);
localparam integer WORD_BITS    = (WORDS_PER_ROW <= 1) ? 1 : $clog2(WORDS_PER_ROW);
localparam integer LINEBUF_SYNC_READ =
    LINEBUF_REGISTER_READ || LINEBUF_NOREG_SYNC_READ;

reg [2:0]  slot_valid;
reg [2:0]  slot_epoch;
reg [ROW_BITS-1:0] slot_tag0;
reg [ROW_BITS-1:0] slot_tag1;
reg [ROW_BITS-1:0] slot_tag2;
reg [ROW_BITS-1:0] load_row;
reg [1:0]  load_slot;
reg        load_epoch;
reg        video_epoch;
reg        video_started;
reg        active_zoom_2x;
reg [10:0] active_source_x_start;
reg signed [10:0] active_source_y_start;
reg [9:0] active_zoom_row_start;
reg [9:0] active_row_end;
reg [WORD_BITS-1:0] request_word;
reg        load_active;
reg        stream_active;
reg        frame_input_done;
reg        read_ack_ff1;
reg        read_ack_ff2;
reg        read_ack_seen;
reg        pending_valid;
reg        pending_commit;
reg [1:0]  pending_slot;
reg [WORD_BITS-1:0] pending_word;
reg [31:0] source_data_hold;
reg [10:0] source_x_d;
reg [1:0]  source_row_slot_d;
reg        source_row_hit_d;
reg        visible_pixel_d;

wire [31:0] line0_word;
wire [31:0] line1_word;
wire [31:0] line2_word;
wire [10:0] source_x;
wire [10:0] scaled_source_x;
wire [9:0]  source_y;
wire signed [10:0] mapped_y;
wire [12:0] source_x_times3;
wire [11:0] source_y_times3;
wire signed [15:0] pan_x_effective = ENABLE_PAN ? pan_x : 16'sd0;
wire signed [15:0] pan_y_effective = ENABLE_PAN ? pan_y : 16'sd0;
wire [9:0] zoom_row_start = ZOOM_ROW_START + pan_y_effective;
wire [9:0] first_row = zoom_2x ? zoom_row_start :
                      pan_y_effective[15] ? 10'd0 : pan_y_effective[9:0];
wire [9:0] row_count = zoom_2x ? SRC_H/2 :
                      SRC_H - (pan_y_effective[15] ? -pan_y_effective : pan_y_effective);
wire [20:0] frame_word_count = WORDS_PER_ROW * row_count;
wire [20:0] zoom_word_offset;
generate if (WORDS_PER_ROW == 480) begin : g_zoom_offset_480
    assign zoom_word_offset = ({11'd0, first_row} << 9) -
                              ({11'd0, first_row} << 5);
end else begin : g_zoom_offset_generic
    assign zoom_word_offset = WORDS_PER_ROW * first_row;
end endgenerate
wire        source_row_hit;
wire [1:0]  source_row_slot;
wire [WORD_BITS-1:0] source_word_addr;
wire        read_fire;
wire        write_back;
wire        response_fire;
wire [31:0] write_back_data;
wire        pending_last;
wire        free_slot0;
wire        free_slot1;
wire        free_slot2;
wire        display_epoch;
wire        preload_epoch;
wire        pixel_row_hit = LINEBUF_SYNC_READ ? source_row_hit_d : source_row_hit;
reg  [6:0]  museum_move_step;
reg signed [3:0] museum_move_factor;
reg  [10:0] museum_panel_left;
reg  [10:0] museum_panel_left_next;
reg  signed [11:0] museum_source_offset;
reg  signed [11:0] museum_source_offset_next;
// Combine the two origins before the pixel mapping, not after it. Modular
// 11-bit addition is unchanged, but the raster no longer crosses two adders.
wire [10:0] museum_source_start = active_source_x_start + museum_source_offset;
wire museum_panel_hit = museum_recenter_active &&
                        video_x >= museum_panel_left &&
                        video_x < museum_panel_left + 11'd256;

assign source_read_base_addr = source_base_addr +
                               zoom_word_offset;
assign source_read_len = frame_word_count;
// The vendor asynchronous FIFO registers dout.  empty only qualifies a pop;
// commit the word after valid confirms it has reached read_data.
assign source_read_en  = stream_active && load_active && !pending_valid &&
                         !(FIFO_RESPONSE_REGISTER && pending_commit) &&
                         !source_fifo_empty;
assign read_fire       = source_read_en;
assign pending_last    = (pending_word == WORDS_PER_ROW - 1);
assign response_fire   = pending_valid && source_fifo_valid;
assign write_back      = FIFO_RESPONSE_REGISTER ? pending_commit : response_fire;
assign write_back_data = FIFO_RESPONSE_REGISTER ? source_data_hold : source_read_data;

generate
    if ((SRC_W == 960) && (DST_W == 1280)) begin : g_x_3_over_4
        // Widen before 3*x.  Keeping this calculation at video_x width
        // wraps at x=683, so the second half of a scan line addresses the
        // wrong source pixels.
        assign source_x_times3 = {2'b00, video_x} + ({2'b00, video_x} << 1);
        assign scaled_source_x = active_zoom_2x ? (source_x_times3 >> 3) :
                                                 (source_x_times3 >> 2);
    end else begin : g_x_generic
        assign scaled_source_x = active_zoom_2x ? ((video_x * SRC_W) / (DST_W * 2)) :
                                                 ((video_x * SRC_W) / DST_W);
    end
    if ((SRC_H == 540) && (DST_H == 720)) begin : g_y_3_over_4
        // Likewise, 3*y needs 12 bits.  Without widening it wraps at y=342
        // and makes the display request rows which were already released.
        assign source_y_times3 = {2'b00, video_y} + ({2'b00, video_y} << 1);
        // Capture the selected origin at source_start, as on the X path.
        // Keep 11-bit wrapping for negative pan and blanking coordinates.
        wire [9:0] scaled_y = active_zoom_2x ? {1'b0,source_y_times3[11:3]} :
                                              source_y_times3[11:2];
        assign mapped_y = active_source_y_start + {1'b0,scaled_y};
    end else begin : g_y_generic
        assign mapped_y = active_source_y_start + (active_zoom_2x ?
                          ((video_y * SRC_H) / (DST_H * 2)) :
                          ((video_y * SRC_H) / DST_H));
    end
endgenerate

wire in_picture = source_x < SRC_W && !mapped_y[10] && mapped_y < SRC_H;
// Clamp negative Y only for row-retirement comparisons; blank pixels must not
// release row zero before it is visible. Source reads cover visible rows only.
assign source_y = mapped_y[10] ? 10'd0 : mapped_y[9:0];

// During the museum overview half of mode 5, copy the selected 192-pixel
// source ROI into a 256-pixel destination panel which moves to/from center.
// The 3/4 source mapping stays unchanged, so the pixels are translated rather
// than stretched.  Powers-of-two make all five 64-frame paths exact.
always @(*) begin
    museum_move_step = museum_recenter_closing ?
                       museum_recenter_progress[6:0] :
                       8'd128 - museum_recenter_progress;
    if (museum_move_step > 7'd64)
        museum_move_step = 7'd64;
    museum_panel_left_next = 11'd512;
    museum_move_factor = 4'sd0;
    case (museum_recenter_origin)
        3'd0: begin
            museum_panel_left_next = {museum_move_step, 3'b000};
            museum_move_factor = -4'sd6;
        end
        3'd1: begin
            museum_panel_left_next = 11'd256 + {museum_move_step, 2'b00};
            museum_move_factor = -4'sd3;
        end
        3'd2: begin
            museum_panel_left_next = 11'd512;
            museum_move_factor = 4'sd0;
        end
        3'd3: begin
            museum_panel_left_next = 11'd768 - {museum_move_step, 2'b00};
            museum_move_factor = 4'sd3;
        end
        default: begin
            museum_panel_left_next = 11'd1024 - {museum_move_step, 3'b000};
            museum_move_factor = 4'sd6;
        end
    endcase
    // Variable signed factor permits a DSP instead of chained add/negate LUTs.
    // Keep the existing single-cycle geometry latency and exact pixel mapping.
    museum_source_offset_next = $signed({1'b0, museum_move_step}) *
                                museum_move_factor;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        museum_panel_left <= 11'd0;
        museum_source_offset <= 12'sd0;
    end else begin
        museum_panel_left <= museum_panel_left_next;
        museum_source_offset <= museum_source_offset_next;
    end
end

assign source_x = scaled_source_x +
                 (museum_panel_hit ? museum_source_start : active_source_x_start);

assign source_word_addr = source_x[WORD_BITS:1];
assign display_epoch = video_epoch ^
                       (video_started && video_de && video_x == 11'd0 &&
                        video_y == 10'd0);
assign preload_epoch = video_started ? ~video_epoch : video_epoch;
assign source_row_hit  = in_picture && (slot_valid[0] && slot_epoch[0] == display_epoch &&
                         (slot_tag0 == mapped_y[9:0]) ? 1'b1 :
                         slot_valid[1] && slot_epoch[1] == display_epoch &&
                         (slot_tag1 == mapped_y[9:0]) ? 1'b1 :
                         slot_valid[2] && slot_epoch[2] == display_epoch &&
                         (slot_tag2 == mapped_y[9:0]) ? 1'b1 : 1'b0);
assign source_row_slot = (slot_valid[0] && slot_epoch[0] == display_epoch &&
                          (slot_tag0 == mapped_y[9:0])) ? 2'd0 :
                         (slot_valid[1] && slot_epoch[1] == display_epoch &&
                          (slot_tag1 == mapped_y[9:0])) ? 2'd1 : 2'd2;

assign free_slot0 = !slot_valid[0];
assign free_slot1 = !slot_valid[1];
assign free_slot2 = !slot_valid[2];

// Start only after three consecutive source rows have arrived.  This gives
// the SDRAM reader enough lead time before the visible raster consumes row 1.
assign frame_ready = slot_valid[0] &&
                     (slot_tag0 == active_zoom_row_start) &&
                     slot_epoch[0] == preload_epoch &&
                     slot_valid[1] &&
                     (slot_tag1 == active_zoom_row_start + 1) &&
                     slot_epoch[1] == preload_epoch &&
                     slot_valid[2] &&
                     (slot_tag2 == active_zoom_row_start + 2) &&
                     slot_epoch[2] == preload_epoch;

al_dp_ram32 #(.ADDR_WIDTH(WORD_BITS), .DEPTH(WORDS_PER_ROW),
              .REGISTER_READ(LINEBUF_REGISTER_READ),
              .NOREG_SYNC_READ(LINEBUF_NOREG_SYNC_READ)) u_line0 (
    .clk(clk), .wr_en(write_back && pending_slot == 2'd0),
    .wr_addr(pending_word), .wr_data(write_back_data),
    .rd_addr(source_word_addr), .rd_data(line0_word)
);
al_dp_ram32 #(.ADDR_WIDTH(WORD_BITS), .DEPTH(WORDS_PER_ROW),
              .REGISTER_READ(LINEBUF_REGISTER_READ),
              .NOREG_SYNC_READ(LINEBUF_NOREG_SYNC_READ)) u_line1 (
    .clk(clk), .wr_en(write_back && pending_slot == 2'd1),
    .wr_addr(pending_word), .wr_data(write_back_data),
    .rd_addr(source_word_addr), .rd_data(line1_word)
);
al_dp_ram32 #(.ADDR_WIDTH(WORD_BITS), .DEPTH(WORDS_PER_ROW),
              .REGISTER_READ(LINEBUF_REGISTER_READ),
              .NOREG_SYNC_READ(LINEBUF_NOREG_SYNC_READ)) u_line2 (
    .clk(clk), .wr_en(write_back && pending_slot == 2'd2),
    .wr_addr(pending_word), .wr_data(write_back_data),
    .rd_addr(source_word_addr), .rd_data(line2_word)
);

// A registered BRAM output is consumed one clock after its address is
// presented.  Keep the selected pixel visible during horizontal blanking so
// the pipeline can pre-load column zero before the next active line; the
// video-delay block still masks all blanking pixels at the HDMI output.
assign pixel565 = ((!video_de && !LINEBUF_SYNC_READ) || !pixel_row_hit) ? 16'h0000 :
                  (LINEBUF_SYNC_READ ?
                   (!source_row_hit_d ? 16'h0000 :
                    (source_row_slot_d == 2'd0 ?
                     (source_x_d[0] ? line0_word[15:0] : line0_word[31:16]) :
                     source_row_slot_d == 2'd1 ?
                     (source_x_d[0] ? line1_word[15:0] : line1_word[31:16]) :
                     (source_x_d[0] ? line2_word[15:0] : line2_word[31:16]))) :
                   (source_row_slot == 2'd0 ?
                    (source_x[0] ? line0_word[15:0] : line0_word[31:16]) :
                    source_row_slot == 2'd1 ?
                    (source_x[0] ? line1_word[15:0] : line1_word[31:16]) :
                    (source_x[0] ? line2_word[15:0] : line2_word[31:16])));

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        source_read_req   <= 1'b0;
        read_ack_ff1      <= 1'b0;
        read_ack_ff2      <= 1'b0;
        read_ack_seen     <= 1'b0;
        stream_active     <= 1'b0;
        load_active       <= 1'b0;
        frame_input_done  <= 1'b0;
        source_frame_done <= 1'b0;
        underflow         <= 1'b0;
        slot_valid        <= 3'b000;
        slot_epoch        <= 3'b000;
        slot_tag0         <= {ROW_BITS{1'b0}};
        slot_tag1         <= {ROW_BITS{1'b0}};
        slot_tag2         <= {ROW_BITS{1'b0}};
        load_row          <= {ROW_BITS{1'b0}};
        load_slot         <= 2'd0;
        load_epoch        <= 1'b0;
        video_epoch       <= 1'b0;
        video_started     <= 1'b0;
        active_zoom_2x    <= 1'b0;
        active_source_x_start <= 11'd0;
        active_source_y_start <= 11'sd0;
        active_row_end     <= SRC_H-1;
        active_zoom_row_start <= ZOOM_ROW_START;
        request_word      <= {WORD_BITS{1'b0}};
        pending_valid     <= 1'b0;
        pending_commit    <= 1'b0;
        pending_slot      <= 2'd0;
        pending_word      <= {WORD_BITS{1'b0}};
        source_data_hold  <= 32'd0;
        source_x_d        <= 11'd0;
        source_row_slot_d <= 2'd0;
        source_row_hit_d  <= 1'b0;
        visible_pixel_d   <= 1'b0;
    end else begin
        source_x_d        <= source_x;
        source_row_slot_d <= source_row_slot;
        source_row_hit_d  <= source_row_hit;
        visible_pixel_d   <= video_de && in_picture && !source_start;
        read_ack_ff1 <= source_read_ack;
        read_ack_ff2 <= read_ack_ff1;

        if (source_start) begin
            source_read_req   <= 1'b1;
            read_ack_seen     <= 1'b0;
            stream_active     <= 1'b0;
            load_active       <= 1'b0;
            frame_input_done  <= 1'b0;
            source_frame_done <= 1'b0;
            underflow         <= 1'b0;
            slot_valid        <= 3'b000;
            slot_epoch        <= 3'b000;
            active_zoom_2x    <= zoom_2x;
            // Zoom origin is constant for this source transaction: add it
            // here, not in every pixel's mapping chain. The output is 11 bits.
            active_source_x_start <= pan_x_effective + (zoom_2x ? SRC_W/4 : 0);
            active_source_y_start <= zoom_2x ? {1'b0,zoom_row_start} :
                                               {pan_y_effective[9],pan_y_effective[9:0]};
            active_zoom_row_start <= first_row;
            active_row_end     <= first_row + row_count - 1'b1;
            load_row          <= first_row;
            load_slot         <= 2'd0;
            // A restarted stream preloads the epoch that the next frame-start
            // will select.  video_epoch itself changes at that frame-start.
            load_epoch        <= video_started ? ~video_epoch : video_epoch;
            request_word      <= {WORD_BITS{1'b0}};
            pending_valid     <= 1'b0;
            pending_commit    <= 1'b0;
        end else begin
            pending_commit <= 1'b0;
            if (FIFO_RESPONSE_REGISTER && response_fire) begin
                source_data_hold <= source_read_data;
                pending_commit   <= 1'b1;
            end
            if (source_read_req && read_ack_ff2) begin
                source_read_req <= 1'b0;
                read_ack_seen   <= 1'b1;
                stream_active   <= 1'b1;
            end

            if (video_started && video_de && video_x == 11'd0 && video_y == 10'd0)
                video_epoch <= ~video_epoch;
            if (video_de)
                video_started <= 1'b1;

            // Release rows which can no longer be referenced by the raster.
            // Tags include a loop epoch, so next-frame row 0 never aliases
            // current-frame row 0 while both are prefetched.
            if (video_de && (video_x == 11'd0)) begin
                if (video_y == 10'd0 && slot_valid[0] &&
                    slot_epoch[0] != display_epoch)
                    slot_valid[0] <= 1'b0;
                else if (slot_valid[0] && slot_epoch[0] == display_epoch &&
                         (slot_tag0 < source_y))
                    slot_valid[0] <= 1'b0;
                if (video_y == 10'd0 && slot_valid[1] &&
                    slot_epoch[1] != display_epoch)
                    slot_valid[1] <= 1'b0;
                else if (slot_valid[1] && slot_epoch[1] == display_epoch &&
                         (slot_tag1 < source_y))
                    slot_valid[1] <= 1'b0;
                if (video_y == 10'd0 && slot_valid[2] &&
                    slot_epoch[2] != display_epoch)
                    slot_valid[2] <= 1'b0;
                else if (slot_valid[2] && slot_epoch[2] == display_epoch &&
                         (slot_tag2 < source_y))
                    slot_valid[2] <= 1'b0;
            end

            // Pick a free line slot before accepting the next source row.
            if (stream_active && !load_active && !frame_input_done) begin
                if (free_slot0) begin
                    load_slot    <= 2'd0;
                    request_word <= {WORD_BITS{1'b0}};
                    load_active  <= 1'b1;
                end else if (free_slot1) begin
                    load_slot    <= 2'd1;
                    request_word <= {WORD_BITS{1'b0}};
                    load_active  <= 1'b1;
                end else if (free_slot2) begin
                    load_slot    <= 2'd2;
                    request_word <= {WORD_BITS{1'b0}};
                    load_active  <= 1'b1;
                end
            end

            if (write_back) begin
                if (pending_last) begin
                    if (pending_slot == 2'd0) begin
                        slot_valid[0] <= 1'b1;
                        slot_epoch[0] <= load_epoch;
                        slot_tag0     <= load_row;
                    end else if (pending_slot == 2'd1) begin
                        slot_valid[1] <= 1'b1;
                        slot_epoch[1] <= load_epoch;
                        slot_tag1     <= load_row;
                    end else begin
                        slot_valid[2] <= 1'b1;
                        slot_epoch[2] <= load_epoch;
                        slot_tag2     <= load_row;
                    end

                    load_active <= 1'b0;
                    if (load_row == active_row_end) begin
                        source_frame_done <= 1'b1;
                        // frame_fifo_read already loops at source_base_addr.
                        // Keep consuming it and wrap the line tag instead of
                        // asynchronously clearing the FIFO once per frame.
                        load_row <= active_zoom_row_start;
                        load_epoch <= ~load_epoch;
                    end else begin
                        load_row <= load_row + 1'b1;
                    end
                end
            end

            // Keep one request in flight until the generated FIFO reports
            // that the matching response is valid.
            if (write_back && pending_word != WORDS_PER_ROW - 1)
                request_word <= pending_word + 1'b1;

            if (read_fire) begin
                pending_valid <= 1'b1;
                pending_slot  <= load_slot;
                pending_word  <= request_word;
            end else if (response_fire) begin
                pending_valid <= 1'b0;
            end

            // Keep the first missed visible pixel sticky even after the
            // three-row window loses frame_ready; otherwise a mid-frame
            // underrun is invisible to the board diagnostics.
            if (visible_pixel_d && !source_row_hit_d)
                underflow <= 1'b1;
        end
    end
end

endmodule

`default_nettype wire
