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
    parameter integer FIFO_RESPONSE_REGISTER = 0
) (
    input  wire        clk,
    input  wire        rst_n,

    // Start one sequential source-frame transaction during video blanking.
    input  wire        source_start,
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

wire [31:0] line0_word;
wire [31:0] line1_word;
wire [31:0] line2_word;
wire [10:0] source_x;
wire [9:0]  source_y;
wire [12:0] source_x_times3;
wire [11:0] source_y_times3;
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
wire        pixel_row_hit = LINEBUF_SYNC_READ ? source_row_hit_d : source_row_hit;

assign source_read_base_addr = source_base_addr;
assign source_read_len = FRAME_WORDS;
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
        assign source_x = source_x_times3 >> 2;
    end else begin : g_x_generic
        assign source_x = (video_x * SRC_W) / DST_W;
    end
    if ((SRC_H == 540) && (DST_H == 720)) begin : g_y_3_over_4
        // Likewise, 3*y needs 12 bits.  Without widening it wraps at y=342
        // and makes the display request rows which were already released.
        assign source_y_times3 = {2'b00, video_y} + ({2'b00, video_y} << 1);
        assign source_y = source_y_times3 >> 2;
    end else begin : g_y_generic
        assign source_y = (video_y * SRC_H) / DST_H;
    end
endgenerate

assign source_word_addr = source_x[WORD_BITS:1];
assign display_epoch = video_epoch ^
                       (video_started && video_de && video_x == 11'd0 &&
                        video_y == 10'd0);
assign source_row_hit  = slot_valid[0] && slot_epoch[0] == display_epoch &&
                         (slot_tag0 == source_y) ? 1'b1 :
                         slot_valid[1] && slot_epoch[1] == display_epoch &&
                         (slot_tag1 == source_y) ? 1'b1 :
                         slot_valid[2] && slot_epoch[2] == display_epoch &&
                         (slot_tag2 == source_y) ? 1'b1 : 1'b0;
assign source_row_slot = (slot_valid[0] && slot_epoch[0] == display_epoch &&
                          (slot_tag0 == source_y)) ? 2'd0 :
                         (slot_valid[1] && slot_epoch[1] == display_epoch &&
                          (slot_tag1 == source_y)) ? 2'd1 : 2'd2;

assign free_slot0 = !slot_valid[0];
assign free_slot1 = !slot_valid[1];
assign free_slot2 = !slot_valid[2];

// Start only after three consecutive source rows have arrived.  This gives
// the SDRAM reader enough lead time before the visible raster consumes row 1.
assign frame_ready = slot_valid[0] && (slot_tag0 == {ROW_BITS{1'b0}}) &&
                     slot_epoch[0] == video_epoch &&
                     slot_valid[1] && (slot_tag1 == {{(ROW_BITS-1){1'b0}}, 1'b1}) &&
                     slot_epoch[1] == video_epoch &&
                     slot_valid[2] && (slot_tag2 == {{(ROW_BITS-2){1'b0}}, 2'd2}) &&
                     slot_epoch[2] == video_epoch;

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
        request_word      <= {WORD_BITS{1'b0}};
        pending_valid     <= 1'b0;
        pending_commit    <= 1'b0;
        pending_slot      <= 2'd0;
        pending_word      <= {WORD_BITS{1'b0}};
        source_data_hold  <= 32'd0;
        source_x_d        <= 11'd0;
        source_row_slot_d <= 2'd0;
        source_row_hit_d  <= 1'b0;
    end else begin
        source_x_d        <= source_x;
        source_row_slot_d <= source_row_slot;
        source_row_hit_d  <= source_row_hit;
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
            load_row          <= {ROW_BITS{1'b0}};
            load_slot         <= 2'd0;
            load_epoch        <= (video_started && !video_de) ?
                                 ~video_epoch : video_epoch;
            // video_de is intentionally gated low while the parent waits for
            // frame_ready.  Advance the epoch here as well as load_epoch;
            // otherwise a restart preloads the next epoch but can never make
            // frame_ready true, leaving KEY2 permanently black.
            if (video_started && !video_de)
                video_epoch <= ~video_epoch;
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
                    if (load_row == SRC_H - 1) begin
                        source_frame_done <= 1'b1;
                        // frame_fifo_read already loops at source_base_addr.
                        // Keep consuming it and wrap the line tag instead of
                        // asynchronously clearing the FIFO once per frame.
                        load_row <= {ROW_BITS{1'b0}};
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
            if (video_de && !source_row_hit)
                underflow <= 1'b1;
        end
    end
end

endmodule

`default_nettype wire
