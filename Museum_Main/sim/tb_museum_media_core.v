`timescale 1ns / 1ps
`default_nettype none

// Integration-only simulation for the 1280x720 media top.  The TF loader,
// writer and SDRAM are replaced by deterministic models; the production
// video timing, line buffer, delay and post-processing remain unchanged.
module tb_museum_media_core #(
    parameter integer TEST_REGISTERED = 0,
    parameter integer TEST_V26_OUTPUT_PIPELINE = 0,
    parameter integer TEST_FIFO_RESPONSE_REGISTER = 0,
    parameter integer LONG_CHECK = 0,
    parameter integer TIMING_TEST = 0,
    parameter integer RESET_STRESS = 0,
    parameter integer PRELOAD_TEST = 0,
    parameter integer MULTI5_TEST = 0,
    parameter integer OUTPUT_ROUTE_TEST = 0,
    parameter integer PHASE1_TEST = 0,
    parameter integer PHASE2_TEST = 0,
    parameter integer PHASE3_TEST = 0,
    parameter integer PHASE4_TEST = 0,
    parameter integer PHASE5_TEST = 0,
    parameter integer SD_ABORT_TEST = 0,
    parameter integer MAIN3_RECOVERY_TEST = 0,
    parameter integer MAIN3_ZOOM_TEST = 0,
    parameter integer MAIN4_EMERGENCY_TEST = 0,
    parameter integer MAIN5_CONTROLS_TEST = 0,
    parameter integer MAIN5_REMOTE_TEST = 0,
    parameter integer PLL_STARTUP_TEST = 0,
    parameter integer LOCAL_MANUAL_TEST = 0,
    parameter integer LIGHT_BAND_TEST = 0
);
    reg clk_50m = 1'b0;
    reg [3:0] key_n = 4'b1111;
    reg [3:0] sw = 4'b0000;
    reg sd_miso = 1'b1;
    integer mode_check, progress_check;
    reg [2:0] saved_mode;
    reg [7:0] saved_progress;
    reg light_band_pass=0;
    reg pll_startup_pass=0;
    reg pll_system_lock=0, pll_video_lock=0;
    reg remote_command_valid = 1'b0;
    reg [7:0] remote_command_type = 8'd0;
    reg [63:0] remote_command_payload = 64'd0;
    wire remote_command_done;
    wire [7:0] remote_command_result;
    wire [95:0] main5_display;
    wire manual_key_return;
    generate if (MAIN5_REMOTE_TEST) begin : g_manual_return_check
        assign manual_key_return = dut.g_museum_lecture_controller.u_museum_lecture_controller.key_return;
    end else begin : g_no_manual_return_check
        assign manual_key_return = 1'b0;
    end endgenerate

    wire [3:0] led;
    wire [7:0] seg_data, seg_sel;
    wire sd_clk, sd_mosi, sd_cs_n;
    wire vga_hs, vga_vs;
    wire [11:0] vga_d;
    wire hdmi1_clk_p, hdmi1_d2_p, hdmi1_d1_p, hdmi1_d0_p;

    localparam integer TB_VIDEO_W = TIMING_TEST ? 128 : 32;
    localparam integer TB_VIDEO_H = TIMING_TEST ? 72  : 24;
    localparam integer TB_SOURCE_W = TIMING_TEST ? 96 : 24;
    localparam integer TB_SOURCE_H = TIMING_TEST ? 54 : 18;

`ifdef V66_TOP
    museum_media_core #(
`else
    top #(
`endif
        .VIDEO_W(TB_VIDEO_W), .VIDEO_H(TB_VIDEO_H), .VIDEO_BURST_WORDS(4),
        .VIDEO_MODE_1280(1),
        .ENABLE_OSD(PHASE1_TEST || PHASE2_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST),
        .ENABLE_FADE(PHASE3_TEST || PHASE4_TEST || PHASE5_TEST || LIGHT_BAND_TEST || MAIN5_CONTROLS_TEST),
        .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
        .PRELOAD_BOTH_IMAGES(PRELOAD_TEST || MULTI5_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST || MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
        .MULTI_IMAGE_BMP(MULTI5_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST || MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
        .MULTI_FRAME_PRELOAD(MULTI5_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST || MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
        .VIDEO_FRAME_COUNT((MULTI5_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST || MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST) ? 5 : 2),
        .AUTO_PERIOD_CYCLES(PHASE4_TEST ? 32 : 250000000),
        .SOURCE_W(TB_SOURCE_W), .SOURCE_H(TB_SOURCE_H),
        .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(TEST_REGISTERED),
`ifdef V66_TOP
        .LINEBUF_NOREG_SYNC_READ(0),
        .ENABLE_MAIN3(MAIN3_RECOVERY_TEST || MAIN3_ZOOM_TEST || MAIN4_EMERGENCY_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
        .ENABLE_MAIN4(MAIN4_EMERGENCY_TEST || MAIN5_REMOTE_TEST),
        .ENABLE_MAIN5_CONTROLS(MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
        .ENABLE_MAIN5_REMOTE(MAIN5_REMOTE_TEST),
        .ENABLE_LOCAL_MANUAL_TEST(LOCAL_MANUAL_TEST),
        .KEY_DEBOUNCE_BITS(LOCAL_MANUAL_TEST ? 2 : 19),
        .ENABLE_MUSEUM_OVERVIEW(MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
        .ENABLE_MUSEUM_LECTURE(MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST),
`endif
        .LINEBUF_V26_OUTPUT_PIPELINE(TEST_V26_OUTPUT_PIPELINE),
        .LINEBUF_FIFO_RESPONSE_REGISTER(TEST_FIFO_RESPONSE_REGISTER),
        .ENABLE_SUBTITLE(OUTPUT_ROUTE_TEST),
        // The production switch point is VIDEO_W+19, after video_delay has
        // drained.  The compact preload raster therefore needs at least 20
        // horizontal blanking clocks; legacy timing tests retain 2 clocks.
        .H_FRONT((PRELOAD_TEST || MULTI5_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST || MAIN3_ZOOM_TEST || MAIN5_CONTROLS_TEST || MAIN5_REMOTE_TEST) ? 22 : 2),
        .H_SYNC(2), .H_BACK(2),
        .V_FRONT(1), .V_SYNC(1), .V_BACK(1)
    ) dut (
        .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
        .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
        .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
        .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
        .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
        .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
`ifdef V66_TOP
        ,.uart_rxd(1'b1), .uart_txd(),
        .remote_command_valid(remote_command_valid),
        .remote_command_type(remote_command_type),
        .remote_command_payload(remote_command_payload),
        .remote_command_done(remote_command_done),
        .remote_command_result(remote_command_result),
        .main5_display(main5_display)
`endif
    );

    always #5 clk_50m = ~clk_50m;

    integer timeout = 0;
    integer active_samples = 0;
    integer nonzero_samples = 0;
    integer first_nonzero_cycle = -1;
    integer long_x = 0;
    integer long_y = 0;
    integer long_frames = 0;
    integer long_mismatch = 0;
    integer long_debug_samples = 0;
    integer long_mismatch_debug = 0;
    integer linebuf_debug_events = 0;
    integer target_index = 0;
    integer primitive_id = 0;
    integer step = 0;
    reg [3:0] old_display_media;
    reg long_prev_de = 1'b0;
    reg long_armed = 1'b0;
    reg seen_run = 1'b0;
    reg [4:0] loader_state_prev = 5'd31;
    reg preload_ready_toggle;

    function [23:0] expected_rgb;
        input integer px;
        input integer py;
        integer source_y;
        reg [7:0] red;
        reg [7:0] green;
        reg [7:0] blue;
        reg [15:0] pixel565;
        begin
            if (TIMING_TEST) begin
                // STUB_STORE returns source pixel p as 0x8000|(p&0x7ff).
                // The timing test uses the production 96x54 -> 128x72
                // 3:4 map and checks the actual full-chain output.
                source_y = py * 54 / 72;
                pixel565 = 16'h8000 |
                           (((source_y * 96) + (px * 96 / 128))
                            & 16'h07ff);
            end else begin
                // The real-media SD model contains a 24x18 bottom-up BMP:
                // B=x, G=y, R=x+y.  The 32x24 destination uses a 4:3 map.
                source_y = 17 - (py * 18 / 24);
                red = ((px * 24 / 32) + source_y) & 8'hff;
                green = source_y[7:0];
                blue = (px * 24 / 32) & 8'hff;
                pixel565 = {red[7:3], green[7:2], blue[7:3]};
            end
            expected_rgb = {{pixel565[15:11], pixel565[15:13]},
                            {pixel565[10:5], pixel565[10:9]},
                            {pixel565[4:0], pixel565[4:2]}};
        end
    endfunction

    task send_remote;
        input [7:0] kind;
        input [63:0] payload;
        input [7:0] expected_result;
        begin
            @(negedge clk_50m);
            remote_command_type=kind;
            remote_command_payload=payload;
            remote_command_valid=1'b1;
            @(posedge remote_command_done);
            #1;
            if (remote_command_result !== expected_result)
                $fatal(1,"remote command %h result=%d expected=%d",
                       kind,remote_command_result,expected_result);
            @(negedge clk_50m);
            remote_command_valid=1'b0;
        end
    endtask

    always @(posedge clk_50m) begin
`ifndef STUB_STORE
        if (dut.u_fat32_image_loader.state !== loader_state_prev) begin
            $display("LOADER state=%0d status=%h req=%b lba=%0d bytes=%0d file_found=%b bmp_ok=%b width=%0d height=%0d",
                     dut.u_fat32_image_loader.state,
                     dut.u_fat32_image_loader.status_code,
                     dut.u_fat32_image_loader.sd_sec_read,
                     dut.u_fat32_image_loader.sd_sec_read_addr,
                     dut.u_fat32_image_loader.file_bytes_seen,
                     dut.u_fat32_image_loader.file_found,
                     dut.u_fat32_image_loader.bmp_header_valid,
                     dut.u_fat32_image_loader.bmp_width,
                     dut.u_fat32_image_loader.bmp_height);
            loader_state_prev <= dut.u_fat32_image_loader.state;
        end
`endif
        if (!key_n[0]) begin
            active_samples <= 0;
            nonzero_samples <= 0;
            first_nonzero_cycle <= -1;
            seen_run <= 1'b0;
            long_x <= 0;
            long_y <= 0;
            long_frames <= 0;
            long_mismatch <= 0;
            long_debug_samples <= 0;
            long_mismatch_debug <= 0;
            linebuf_debug_events <= 0;
            long_prev_de <= 1'b0;
            long_armed <= 1'b0;
        end else begin
            if (dut.g_linebuf_scaler.u_linebuf_scaler.read_fire && linebuf_debug_events < 80) begin
                $display("LBREAD t=%0t reqword=%0d slot=%0d row=%0d rddata=%h fifo_empty=%b fifo_valid=%b pending=%b",
                         $time,
                         dut.g_linebuf_scaler.u_linebuf_scaler.request_word,
                         dut.g_linebuf_scaler.u_linebuf_scaler.load_slot,
                         dut.g_linebuf_scaler.u_linebuf_scaler.load_row,
                         dut.read_data, dut.read_fifo_empty, dut.read_fifo_valid,
                         dut.g_linebuf_scaler.u_linebuf_scaler.pending_valid);
                linebuf_debug_events <= linebuf_debug_events + 1;
            end
            if (dut.g_linebuf_scaler.u_linebuf_scaler.write_back && linebuf_debug_events < 80) begin
                $display("LBWRITE t=%0t word=%0d slot=%0d row=%0d data=%h fifo_empty=%b fifo_valid=%b",
                         $time,
                         dut.g_linebuf_scaler.u_linebuf_scaler.pending_word,
                         dut.g_linebuf_scaler.u_linebuf_scaler.pending_slot,
                         dut.g_linebuf_scaler.u_linebuf_scaler.load_row,
                         dut.g_linebuf_scaler.u_linebuf_scaler.source_read_data,
                         dut.read_fifo_empty, dut.read_fifo_valid);
                linebuf_debug_events <= linebuf_debug_events + 1;
            end
            if (dut.video_run)
                seen_run <= 1'b1;
            if (dut.video_de_out) begin
                active_samples <= active_samples + 1;
                if (dut.video_rgb_out != 24'h000000) begin
                    nonzero_samples <= nonzero_samples + 1;
                    if (first_nonzero_cycle < 0)
                        first_nonzero_cycle <= timeout;
                end
            end
            if (LONG_CHECK) begin
                // Arm at the first complete active-line rising edge after
                // video_run.  The timing generator runs before the media
                // loader, so counting DE from reset would compare startup
                // black pixels against image data.
                if (!long_armed) begin
                    if (dut.video_run && dut.video_de_out && !long_prev_de) begin
                        long_armed <= 1'b1;
                        long_x <= 1;
                        long_y <= 0;
                        long_frames <= 0;
                        if (long_debug_samples < 96) begin
                            $display("PIX t=%0t outxy=%0d,%0d intxy=%0d,%0d dxy=%0d,%0d deq=%b deqd=%b rgb=%h pipe=%h unpack=%h vdelay=%h exp=%h srcxy=%0d,%0d hit=%b hitd=%b slot=%0d slotd=%0d xd=%0d pix=%h line=%h/%h/%h tags=%0d,%0d,%0d val=%b",
                                     $time, 0, 0,
                                     dut.video_x_i, dut.video_y_i,
                                     dut.video_x_delayed, dut.video_y_delayed,
                                     dut.g_hdmi_output_register.de_q,
                                     dut.g_hdmi_output_register.de_q_d,
                                     dut.video_rgb_out,
                                     dut.linebuf_pixel565_pipe_reg[319:304],
                                     dut.unpacked_rgb, dut.video_rgb,
                                     expected_rgb(0, 0),
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_x,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_y,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit_d,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_row_slot,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_row_slot_d,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_x_d,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.pixel565,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.line0_word,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.line1_word,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.line2_word,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag0,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag1,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag2,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_valid);
                            long_debug_samples <= long_debug_samples + 1;
                        end
                        if (dut.video_rgb_out !== expected_rgb(0, 0)) begin
                            if (long_mismatch_debug < 40) begin
                                $display("MISM t=%0t xy=%0d,%0d rgb=%h exp=%h hit=%b hitd=%b tags=%0d,%0d,%0d val=%b",
                                         $time, 0, 0, dut.video_rgb_out,
                                         expected_rgb(0, 0),
                                         dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit,
                                         dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit_d,
                                         dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag0,
                                         dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag1,
                                         dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag2,
                                         dut.g_linebuf_scaler.u_linebuf_scaler.slot_valid);
                                long_mismatch_debug <= long_mismatch_debug + 1;
                            end
                            long_mismatch <= long_mismatch + 1;
                        end
                    end
                end else if (dut.video_de_out) begin
                    if ((long_x < 2 || long_x >= TB_VIDEO_W - 2) && long_y < 1)
                        $display("EDGE t=%0t xy=%0d,%0d intxy=%0d,%0d de=%b deq=%b deqd=%b rgbq=%h vde=%b vrgb=%h osd=%h unpack=%h pipe=%h lbpix=%h lbx=%0d lby=%0d ded19=%b ded20=%b",
                                 $time, long_x, long_y, dut.video_x_i, dut.video_y_i,
                                 dut.video_de_out,
                                 dut.g_hdmi_output_register.de_q,
                                 dut.g_hdmi_output_register.de_q_d,
                                 dut.g_hdmi_output_register.rgb_q,
                                 dut.video_de, dut.video_rgb,
                                 dut.video_osd_rgb, dut.unpacked_rgb,
                                 dut.linebuf_pixel565_pipe_reg[319:304],
                                 dut.g_linebuf_scaler.u_linebuf_scaler.pixel565,
                                 dut.linebuf_video_x, dut.video_y_i,
                                 dut.u_video_delay.de_d[19], dut.u_video_delay.de_d[20]);
                    if (long_debug_samples < 96) begin
                        $display("PIX t=%0t outxy=%0d,%0d intxy=%0d,%0d dxy=%0d,%0d deq=%b deqd=%b rgb=%h pipe=%h unpack=%h vdelay=%h exp=%h srcxy=%0d,%0d hit=%b hitd=%b slot=%0d slotd=%0d xd=%0d pix=%h line=%h/%h/%h tags=%0d,%0d,%0d val=%b",
                                 $time, long_x, long_y,
                                 dut.video_x_i, dut.video_y_i,
                                 dut.video_x_delayed, dut.video_y_delayed,
                                 dut.g_hdmi_output_register.de_q,
                                 dut.g_hdmi_output_register.de_q_d,
                                 dut.video_rgb_out,
                                 dut.linebuf_pixel565_pipe_reg[319:304],
                                 dut.unpacked_rgb, dut.video_rgb,
                                 expected_rgb(long_x, long_y),
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_x,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_y,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit_d,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_row_slot,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_row_slot_d,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.source_x_d,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.pixel565,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.line0_word,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.line1_word,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.line2_word,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag0,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag1,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag2,
                                 dut.g_linebuf_scaler.u_linebuf_scaler.slot_valid);
                        long_debug_samples <= long_debug_samples + 1;
                    end
                    if (dut.video_rgb_out !== expected_rgb(long_x, long_y)) begin
                        if (long_mismatch_debug < 40) begin
                            $display("MISM t=%0t xy=%0d,%0d rgb=%h exp=%h hit=%b hitd=%b tags=%0d,%0d,%0d val=%b",
                                     $time, long_x, long_y, dut.video_rgb_out,
                                     expected_rgb(long_x, long_y),
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.source_row_hit_d,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag0,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag1,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_tag2,
                                     dut.g_linebuf_scaler.u_linebuf_scaler.slot_valid);
                            long_mismatch_debug <= long_mismatch_debug + 1;
                        end
                        long_mismatch <= long_mismatch + 1;
                    end
                    if (long_x == TB_VIDEO_W - 1)
                        long_x <= 0;
                    else
                        long_x <= long_x + 1;
                end else if (long_prev_de) begin
                    long_x <= 0;
                    if (long_y == TB_VIDEO_H - 1) begin
                        long_y <= 0;
                        long_frames <= long_frames + 1;
                    end else begin
                        long_y <= long_y + 1;
                    end
                end
                long_prev_de <= dut.video_de_out;
            end
        end
    end

    initial begin
        if (PLL_STARTUP_TEST) begin
            // Model clocks running before lock; no global reset is supplied.
            force dut.u_sys_pll.lock_enable=pll_system_lock;
            force dut.g_video_pll_1280.u_video_pll.lock_enable=pll_video_lock;
            for (step=0;step<4;step=step+1) begin
                pll_system_lock=0; pll_video_lock=0;
                repeat(9+step*7) @(negedge clk_50m);
                if(dut.write_rst_n!==1'b0 || dut.mem_rst_n!==1'b0 || dut.video_rst_n!==1'b0 ||
                   dut.load_active!==1'b0 || dut.frame_valid!==5'd0 || dut.video_run!==1'b0)
                    $fatal(1,"media released before system PLL lock");
                pll_system_lock=1;
                repeat(6) @(negedge clk_50m);
                if(dut.write_rst_n!==1'b1 || dut.mem_rst_n!==1'b1 || dut.video_rst_n!==1'b0)
                    $fatal(1,"system/video PLL reset sequencing");
                // Also let all caches finish before the video clock locks;
                // the initial publication must survive delayed video reset.
                repeat(step==2 ? 1000 : 7+step*5) @(negedge clk_50m);
                if(dut.video_rst_n!==1'b0 || dut.linebuf_source_read_req!==1'b0 || dut.video_run!==1'b0)
                    $fatal(1,"video reader released before video PLL lock");
                if(step==2 && dut.overview_cache_ready!==1'b1)
                    $fatal(1,"late video lock test did not finish overview preload");
                pll_video_lock=1;
                timeout=0;
                while(dut.video_run!==1'b1 && timeout<100000) begin
                    @(negedge clk_50m); timeout=timeout+1;
                end
                if(dut.video_run!==1'b1) $fatal(1,"PLL relock did not restart video");
                long_debug_samples=0;
                repeat(5000) begin
                    @(negedge clk_50m);
                    if(dut.video_de && (^dut.video_rgb)!==1'bx && dut.video_rgb!=0)
                        long_debug_samples=long_debug_samples+1;
                end
                if(long_debug_samples==0) $fatal(1,"PLL startup produced black pixels");
            end
            pll_startup_pass=1;
            $display("PASS PLL startup: delayed independent locks, relock/cache reset and nonblack video x4");
            $finish;
        end
        if (PHASE1_TEST || PHASE2_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST) begin
            force dut.write_rst_n = 1'b0;
            force dut.mem_rst_n = 1'b0;
            force dut.video_rst_n = 1'b0;
        end
        if (PHASE5_TEST)
            sw = 4'b0010;
        key_n[0] = 1'b0;
        #40;
        if (PHASE1_TEST || PHASE2_TEST || PHASE3_TEST || PHASE4_TEST || PHASE5_TEST) begin
            force dut.write_rst_n = 1'b1;
            force dut.mem_rst_n = 1'b1;
            force dut.video_rst_n = 1'b1;
        end
        key_n[0] = 1'b1;
        #20;
        while (timeout < 100000 && !seen_run) begin
            @(posedge clk_50m);
            timeout = timeout + 1;
        end
        if (!seen_run) begin
            $display("FAIL top-chain video_run timeout status=%h frame_done=%b",
                     {dut.status_code, 4'h0, dut.row_index[3:0],
                      dut.image_load_status}, dut.frame_done);
            $finish;
        end

        if (MAIN3_ZOOM_TEST) begin
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.overview_selected_ctrl != 3'd1 || dut.zoom_2x)
                $fatal(1, "overview KEY1 did not select next artifact");
            force dut.key_press_pulse = 4'b0100;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.brightness_level != 2'd1 || dut.contrast_level != 2'd0 ||
                dut.overview_selected_ctrl != 3'd1)
                $fatal(1, "overview KEY3 did not select picture preset");
            force dut.lecture_active = 1'b1;
            force dut.overview_enable_video = 1'b0;
            force dut.transition_active = 1'b0;
            repeat (3) @(negedge clk_50m);
            force dut.key_press_pulse = 4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (!dut.zoom_2x || !dut.detail_zoom_2x ||
                dut.overview_selected_ctrl != 3'd1 || dut.lecture_audio_restart)
                $fatal(1, "lecture KEY1 did not select 2x without returning");
            timeout = 0;
            while (!dut.display_zoom_2x && timeout < 100000) begin
                @(negedge clk_50m); timeout = timeout + 1;
            end
            if (!dut.display_zoom_2x)
                $fatal(1, "2x did not reach frame-boundary video display");
            release dut.transition_active;
            if (dut.transition_active)
                $fatal(1, "2x direct switch restarted transition mode=%0d progress=%0d end=%0d fade=%b",
                       dut.transition_mode, dut.transition_progress,
                       dut.transition_end, dut.fade_out_active);
            force dut.key_press_pulse = 4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.zoom_2x != 2 || dut.detail_zoom_2x != 2)
                $fatal(1, "KEY1 did not select half scale");
            timeout=0;
            while(dut.display_zoom_2x!=2 && timeout<100000)begin
                @(negedge clk_50m);timeout=timeout+1;
            end
            if(timeout==100000)$fatal(1,"Half scale frame-boundary commit timed out");
            force dut.key_press_pulse = 4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.zoom_2x || dut.detail_zoom_2x)
                $fatal(1, "lecture KEY1 did not restore 1x");
            timeout = 0;
            while (dut.display_zoom_2x && timeout < 100000) begin
                @(negedge clk_50m); timeout = timeout + 1;
            end
            if (dut.display_zoom_2x)
                $fatal(1, "1x did not reach frame-boundary video display");
            repeat(6)begin
                @(negedge clk_50m);force dut.key_press_pulse=4'b0001;
                @(negedge clk_50m);release dut.key_press_pulse;
                repeat(6)@(negedge clk_50m);
            end
            if(dut.zoom_2x!=0 || dut.lecture_audio_restart)
                $fatal(1,"rapid KEY1 cycle changed timeline or final scale");
            timeout=0;
            while(dut.display_zoom_2x!=0 && timeout<100000)begin
                @(negedge clk_50m);timeout=timeout+1;
            end
            if(timeout==100000)$fatal(1,"rapid KEY1 latest-scale commit timed out");
            force dut.key_press_pulse = 4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            force dut.key_press_pulse = 4'b0100;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.brightness_level != 2'd0 || dut.contrast_level != 2'd1)
                $fatal(1, "lecture KEY3 did not advance picture preset");
            force dut.lecture_finished = 1'b1;
            repeat (3) @(negedge clk_50m);
            if (dut.zoom_2x || dut.detail_zoom_2x)
                $fatal(1, "zoom persisted into return transition");
            release dut.lecture_finished;
            release dut.lecture_active;
            release dut.overview_enable_video;
            repeat (3) @(negedge clk_50m);
            if (dut.zoom_2x || dut.detail_zoom_2x)
                $fatal(1, "zoom persisted after lecture exit");
            $display("PASS MAIN3 KEY1 select/zoom, KEY3 presets, zoom reset on exit");
            $finish;
        end

        if (LIGHT_BAND_TEST) begin
            force dut.lecture_active=1'b1;
            force dut.lecture_paused_ff2=1'b0;
            force dut.recovery_video_ff2=1'b0;
            force dut.overview_enable_video=1'b0;
            force dut.lecture_final_full_active=1'b0;
            force dut.lecture_display_slot=2'd2;
            #1;
            if(dut.lecture_transition_mode!=0) $fatal(1,"detail1-to-2 fade changed");
            force dut.lecture_display_slot=2'd3;
            #1;
            if(dut.lecture_transition_mode!=7) $fatal(1,"detail2-to-3 selection");
            force dut.lecture_display_slot=2'd0;
            force dut.lecture_final_full_active=1'b1;
            #1;
            if(dut.lecture_transition_mode!=6) $fatal(1,"final-full diamond changed");
            force dut.lecture_display_slot=2'd3;
            force dut.desired_display_media_index=4'd3;
            force dut.detail_zoom_2x_ff2=1'b0;
            force dut.video_frame_tick=1'b0;
            force dut.video_vblank_start=1'b0;
            force dut.video_frame_start=1'b0;
            force dut.linebuf_frame_ready=1'b0;
            @(negedge clk_50m);
            dut.display_media_index=2;
            dut.display_zoom_2x=0;
            dut.video_run=1;
            dut.switch_pending=0;
            repeat(4) @(negedge clk_50m);
            if(!dut.switch_pending || dut.transition_mode!=7) $fatal(1,"band did not start");
            force dut.video_frame_tick=1'b1;
            repeat(8) @(negedge clk_50m);
            force dut.lecture_paused_ff2=1'b1;
            repeat(5) @(negedge clk_50m);
            if(dut.transition_progress!=8) $fatal(1,"paused closing advanced");
            force dut.lecture_paused_ff2=1'b0;
            repeat(24) @(negedge clk_50m);
            force dut.video_frame_tick=1'b0;
            if(dut.transition_progress!=32 || !dut.transition_midpoint_ready)
                $fatal(1,"band close duration");
            force dut.lecture_paused_ff2=1'b1;
            force dut.video_frame_tick=1'b1;
            force dut.video_vblank_start=1'b1;
            repeat(5) @(negedge clk_50m);
            if(dut.transition_progress!=32 || dut.display_media_index!=2)
                $fatal(1,"pause allowed source switch");
            force dut.lecture_paused_ff2=1'b0;
            force dut.video_frame_tick=1'b0;
            @(negedge clk_50m);
            force dut.video_vblank_start=1'b0;
            if(dut.video_run || dut.display_media_index!=3) $fatal(1,"unsafe switch");
            force dut.video_frame_tick=1'b1;
            force dut.video_frame_start=1'b1;
            // Deliberately deny row-prefetch readiness for many frame ticks.
            repeat(80) @(negedge clk_50m);
            if(dut.transition_progress!=32 || dut.video_run || !dut.transition_active)
                $fatal(1,"band opened before new image ready");
            force dut.video_frame_tick=1'b0;
            force dut.linebuf_frame_ready=1'b1;
            @(negedge clk_50m);
            force dut.video_frame_start=1'b0;
            if(!dut.video_run) $fatal(1,"ready image not resumed at frame start");
            force dut.lecture_paused_ff2=1'b1;
            force dut.video_frame_tick=1'b1;
            repeat(7) @(negedge clk_50m);
            if(dut.transition_progress!=32) $fatal(1,"paused opening advanced");
            force dut.lecture_paused_ff2=1'b0;
            repeat(32) @(negedge clk_50m);
            force dut.video_frame_tick=1'b0;
            if(dut.transition_progress!=64 || dut.transition_active)
                $fatal(1,"band open duration/end");
            // Recovery in the middle of an active band must clear busy too.
            dut.transition_progress=8'd40;
            force dut.recovery_video_ff2=1'b1;
            @(negedge clk_50m);
            if(dut.transition_active) $fatal(1,"recovery left band active");
            $display("PASS light-band selection, 64-frame duration, pause, delayed prefetch and recovery");
            light_band_pass=1;
            $finish;
        end
        if (MAIN5_REMOTE_TEST) begin
            force dut.lecture_active=1'b0;
            force dut.lecture_paused=1'b0;
            force dut.recovery_busy=1'b0;
            force dut.emergency_active_50m=1'b0;
            force dut.overview_selected_ctrl=3'd2;
            force dut.lecture_artifact_index=3'd3;
            force dut.lecture_cache_ready=1'b1;
            force dut.lecture_cached_artifact=4'd3;
            force dut.overview_cache_ready=1'b1;
            force dut.audio_prepared=1'b1;
            force dut.subtitle_entry_ready=1'b1;
            sw=4'd3;
            repeat(5) @(negedge clk_50m);
            if(dut.main5_heartbeat[15:0]!==16'h2333 || !dut.main5_heartbeat[71])
                $fatal(1,"overview highlight/target/ready telemetry");
            force dut.lecture_active=1'b1;
            force dut.lecture_paused=1'b1;
            force dut.transition_active_ff2_50m=1'b1;
            force dut.lecture_artifact_index=3'd1;
            #1;
            if(dut.main5_heartbeat[119:112]!==8'd1 || dut.main5_heartbeat[103:96]!==8'd3 ||
               !dut.main5_heartbeat[68] || dut.main5_heartbeat[15:0]!==16'h233f)
                $fatal(1,"paused transition/current lecture/background cache telemetry");
            sw=4'd7;
            repeat(5) @(negedge clk_50m);
            if(dut.main5_heartbeat[11:8]!==4'hf || dut.main5_heartbeat[3:0]!==4'hf)
                $fatal(1,"invalid switches reported ready");
            release dut.lecture_active; release dut.lecture_paused;
            release dut.recovery_busy; release dut.emergency_active_50m;
            release dut.overview_selected_ctrl; release dut.lecture_artifact_index;
            release dut.lecture_cache_ready; release dut.lecture_cached_artifact;
            release dut.overview_cache_ready; release dut.audio_prepared;
            release dut.subtitle_entry_ready; release dut.transition_active_ff2_50m;
            sw=0;
            saved_mode=dut.transition_mode; saved_progress=dut.transition_progress;
            for(mode_check=0;mode_check<8;mode_check=mode_check+1)
              for(progress_check=0;progress_check<256;progress_check=progress_check+1) begin
                force dut.transition_mode=mode_check[2:0];
                force dut.transition_progress=progress_check[7:0];
                #1;
                if(dut.transition_before_midpoint !== (progress_check<(mode_check==5 ? 64 : mode_check==7 ? 32 : 16)) ||
                   dut.transition_before_end !== (progress_check<(mode_check==5 ? 128 : mode_check==7 ? 64 : 32)))
                    $fatal(1,"transition threshold equivalence failed");
              end
            force dut.transition_mode=saved_mode;
            force dut.transition_progress=saved_progress;
            #1;
            release dut.transition_mode; release dut.transition_progress;
            if (dut.binary_to_bcd4(16'd1920) !== 16'h1920 ||
                dut.binary_to_bcd4(16'd1080) !== 16'h1080)
                $fatal(1,"bounded source-size BCD conversion failed");
            force dut.image_source_width = 16'd1920;
            force dut.image_source_height = 16'd1080;
            #1;
            if (dut.image_dimensions_ready) $fatal(1,"stale dimensions accepted");
            repeat (20) @(negedge clk_50m);
            if (!dut.image_dimensions_ready || dut.image_width_bcd !== 16'h1920 ||
                dut.image_height_bcd !== 16'h1080)
                $fatal(1,"sequential dimension conversion failed");
            force dut.image_source_width = 16'd17;
            repeat (5) @(negedge clk_50m);
            force dut.image_source_width = 16'd641;
            force dut.image_source_height = 16'd479;
            repeat (20) @(negedge clk_50m);
            if (!dut.image_dimensions_ready || dut.image_width_bcd !== 16'h0641 ||
                dut.image_height_bcd !== 16'h0479)
                $fatal(1,"dimension conversion restart failed");
            release dut.image_source_width;
            release dut.image_source_height;
            repeat (20) @(negedge clk_50m);
            force dut.transition_active=1'b0;
            repeat(5) @(negedge clk_50m);
            force dut.overview_cache_ready=1'b1;
            force dut.lecture_active=1'b1;
            force dut.lecture_finished=1'b0;
            force dut.lecture_artifact_index=3'd1;
            force dut.manual_cache_ready=1'b0;
            send_remote(8'h17,{8'd1,24'd0,32'd0},8'd4);
            if(dut.manual_mode)$fatal(1,"unsafe overwritten cache entered manual mode");
            force dut.manual_cache_ready=1'b1;
            send_remote(8'h17,{8'd2,24'd0,32'd0},8'd5);
            send_remote(8'h17,{8'd1,24'd0,32'd0},8'd0);
            repeat(5) @(negedge clk_50m);
            if(!dut.manual_mode || dut.audio_stream_enable || !dut.audio_paused ||
               !main5_display[42] || main5_display[40] ||
               dut.main5_heartbeat[103:96]!=8'd5)
                $fatal(1,"manual mode did not silence media/report actual state");
            send_remote(8'h18,{8'd2,8'd3,16'd0,32'd0},8'd5);
            send_remote(8'h18,{8'd1,8'd4,16'd0,32'd0},8'd5);
            send_remote(8'h18,{8'd1,8'd3,16'd0,32'd0},8'd0);
            repeat(3) @(negedge clk_50m);
            if(dut.browse_image_index!=3)$fatal(1,"manual image command not dispatched");
            force dut.lecture_display_slot=2'd0;
            force dut.key_press_pulse=4'b0100;
            @(negedge clk_50m);
            if(!dut.manual_image_pulse || dut.browse_image_index!=1 || !dut.normal_waveform_visible)
                $fatal(1,"production KEY3 must select detail1, not toggle waveform");
            release dut.key_press_pulse;
            force dut.lecture_display_slot=2'd3;
            force dut.key_press_pulse=4'b0100;
            @(negedge clk_50m);
            if(!dut.manual_image_pulse || dut.browse_image_index!=0)
                $fatal(1,"production KEY3 must wrap detail3 to full");
            release dut.key_press_pulse; release dut.lecture_display_slot;
            send_remote(8'h13,{8'd1,8'd1,16'd0,32'd0},8'd0);
            send_remote(8'h14,{8'd3,8'd2,8'd3,8'd3,8'd1,24'd0},8'd0);
            if(!dut.manual_mode)$fatal(1,"manual parameter control changed mode");
            force dut.key_press_pulse=4'b0010;
            #1;
            if(!manual_key_return)
                $fatal(1,"manual KEY2 not wired to cached-image return");
            @(negedge clk_50m); release dut.key_press_pulse;
            if(dut.manual_reload_pending || dut.recovery_state!=0 || !dut.manual_mode)
                $fatal(1,"manual KEY2 must not trigger application reset or mode-off");
            send_remote(8'h17,64'd0,8'd0);
            repeat(3) @(negedge clk_50m);
            if(dut.manual_mode)$fatal(1,"manual mode did not exit");
            if(!dut.manual_reload_pending || !dut.main5_heartbeat[70])
                $fatal(1,"manual exit must advertise pending reload");
            force dut.display_media_index=4'd0;
            repeat(5) @(negedge clk_50m);
            if(dut.recovery_state!=0)$fatal(1,"manual exit skipped return transition");
            force dut.lecture_active=1'b0;
            send_remote(8'h13,{8'd0,8'd1,16'd0,32'd0},8'd4);
            force dut.sd_read_active=1'b1;
            force dut.switch_pending=1'b0;
            force dut.display_media_index=4'd5;
            repeat(5) @(negedge clk_50m);
            if(dut.recovery_state!=0 || !dut.manual_reload_pending || dut.media_session_start)
                $fatal(1,"manual rearm must wait for the old sector, not reset images/SD");
            force dut.sd_read_active=1'b0;
            timeout=0;
            while(dut.manual_reload_pending && timeout<20) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if(!dut.manual_media_restart || dut.manual_reload_pending || dut.recovery_state!=0 ||
               !dut.client_rst_n || !dut.overview_cache_ready)
                $fatal(1,"manual light rearm restart=%b pending=%b state=%d client=%b cache=%b overview=%b switch=%b",
                       dut.manual_media_restart,dut.manual_reload_pending,dut.recovery_state,
                       dut.client_rst_n,dut.overview_cache_ready,dut.manual_overview_ff2,dut.switch_pending);
            release dut.sd_read_active; release dut.switch_pending;
            repeat(5) @(negedge clk_50m);
            send_remote(8'h17,64'd0,8'd0);
            repeat(5) @(negedge clk_50m);
            if(dut.manual_reload_pending || dut.recovery_state!=0)
                $fatal(1,"repeated normal mode caused another reload");
            force dut.audio_stream_enable=1'b1;
            force dut.audio_switch_reset=1'b0;
            force dut.sd_read_abandoned=1'b0;
            force dut.media_session_restart=1'b0;
            repeat(2) @(negedge clk_50m);
            if(!dut.media_session_start)$fatal(1,"registered media session did not start");
            force dut.sd_read_abandoned=1'b1;
            @(negedge clk_50m);
            if(dut.media_session_start)$fatal(1,"abandoned sector allowed fresh media session");
            force dut.sd_read_abandoned=1'b0;
            force dut.audio_switch_reset=1'b1;
            @(negedge clk_50m);
            if(dut.media_session_start)$fatal(1,"resetting PCM FIFO allowed fresh media session");
            force dut.audio_switch_reset=1'b0;
            force dut.media_session_restart=1'b1;
            @(negedge clk_50m);
            if(dut.media_session_start)$fatal(1,"session restart failed to cancel registered start");
            release dut.audio_stream_enable; release dut.audio_switch_reset;
            release dut.sd_read_abandoned; release dut.media_session_restart;
            release dut.display_media_index;
            release dut.overview_cache_ready; release dut.lecture_active;
            release dut.lecture_finished; release dut.lecture_artifact_index;
            release dut.manual_cache_ready;
            $display("PASS MAIN5 manual mode/command validation/silent state report");
            // Diagnostic-only switch/key inputs share the production manual dispatcher.
            force dut.overview_cache_ready=1'b1;
            force dut.lecture_active=1'b0;
            force dut.lecture_finished=1'b0;
            force dut.recovery_busy=1'b0;
            force dut.manual_cache_ready=1'b1;
            sw=5;
            repeat(60) @(negedge clk_50m);
            if(dut.manual_mode !== (LOCAL_MANUAL_TEST!=0))
                $fatal(1,"local diagnostic gate/101 enter");
            if(LOCAL_MANUAL_TEST) begin
                sw=0;
                repeat(60) @(negedge clk_50m);
                force dut.lecture_active=1'b1;
                force dut.lecture_display_slot=2'd0;
                force dut.key_press_pulse=4'b0100;
                @(negedge clk_50m);
                if(!dut.manual_image_pulse || dut.browse_image_index!=1)
                    $fatal(1,"local KEY3 full->detail1 dispatch");
                release dut.key_press_pulse;
                force dut.lecture_display_slot=2'd3;
                force dut.key_press_pulse=4'b0100;
                @(negedge clk_50m);
                if(!dut.manual_image_pulse || dut.browse_image_index!=0)
                    $fatal(1,"local KEY3 detail3->full wrap");
                release dut.key_press_pulse;
                force dut.transition_active_ff2_50m=1'b1;
                force dut.key_press_pulse=4'b0100;
                @(negedge clk_50m);
                if(dut.manual_image_pulse)$fatal(1,"local key accepted during transition");
                release dut.key_press_pulse;
                release dut.transition_active_ff2_50m;
                force dut.manual_cache_ready=1'b0;
                force dut.key_press_pulse=4'b0100;
                @(negedge clk_50m);
                if(dut.manual_image_pulse)$fatal(1,"local key accepted with incomplete cache");
                release dut.key_press_pulse;
                force dut.manual_cache_ready=1'b1;
                // A short intermediate switch code must not leave manual mode.
                sw=6; repeat(5) @(negedge clk_50m);
                sw=0; repeat(60) @(negedge clk_50m);
                if(!dut.manual_mode)$fatal(1,"switch bounce accepted");
                sw=6; repeat(60) @(negedge clk_50m);
                if(dut.manual_mode)$fatal(1,"110 did not leave manual mode");
                force dut.lecture_active=1'b0;
                force dut.display_media_index=4'd5;
                force dut.switch_pending=1'b0;
                force dut.sd_read_active=1'b0;
                repeat(8) @(negedge clk_50m);
                if(dut.manual_reload_pending)$fatal(1,"local mode-off did not rearm at overview");
                release dut.display_media_index; release dut.switch_pending;
                release dut.sd_read_active;
                sw=5; repeat(60) @(negedge clk_50m);
                if(!dut.manual_mode)$fatal(1,"second manual entry failed");
                force dut.client_rst_n=1'b0;
                repeat(3) @(negedge clk_50m);
                release dut.client_rst_n;
                repeat(60) @(negedge clk_50m);
                if(dut.manual_mode)$fatal(1,"recovery reissued held 101 code");
                sw=0; repeat(60) @(negedge clk_50m);
                force dut.main5_remote_busy=1'b1;
                sw=5; repeat(60) @(negedge clk_50m);
                if(dut.manual_mode)$fatal(1,"busy mode request accepted");
                release dut.main5_remote_busy;
                repeat(60) @(negedge clk_50m);
                if(dut.manual_mode)$fatal(1,"rejected mode request replayed later");
                sw=0; repeat(60) @(negedge clk_50m);
                sw=5; repeat(60) @(negedge clk_50m);
                if(!dut.manual_mode)$fatal(1,"fresh mode request after busy failed");
                sw=6; repeat(60) @(negedge clk_50m);
                force dut.display_media_index=4'd5;
                force dut.switch_pending=1'b0;
                force dut.sd_read_active=1'b0;
                repeat(8) @(negedge clk_50m);
                if(dut.manual_reload_pending)$fatal(1,"local final mode-off did not rearm");
                release dut.display_media_index; release dut.switch_pending;
                release dut.sd_read_active;
                release dut.lecture_display_slot;
                $display("PASS local manual enter/cycle/wrap/busy/cache/bounce/exit/recovery");
            end
            sw=0; repeat(60) @(negedge clk_50m);
            release dut.overview_cache_ready; release dut.lecture_active;
            release dut.lecture_finished; release dut.recovery_busy;
            release dut.manual_cache_ready;
            send_remote(8'h13,{8'd1,8'd1,16'd0,32'd0},8'd0);
            timeout=0;
            while (dut.main5_preset_applied!=8'd1 && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (dut.main5_preset_applied!=8'd1 ||
                dut.main5_brightness_applied!=3'd5 ||
                dut.main5_contrast_applied!=3'd3 ||
                dut.main5_saturation_applied!=3'd4 ||
                dut.main5_temperature_applied!=3'd4)
                $fatal(1,"preset did not apply atomically");
            send_remote(8'h14,{8'd7,8'd3,8'd4,8'd5,8'd1,8'd0,16'd0},8'd5);
            if (dut.main5_preset_applied!=8'd1)
                $fatal(1,"invalid adjust changed preset");
            send_remote(8'h14,{8'd4,8'd3,8'd4,8'd5,8'd1,8'd0,16'd0},8'd0);
            timeout=0;
            while (dut.main5_preset_applied!=8'hff && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (dut.main5_preset_applied!=8'hff ||
                dut.main5_brightness_applied!=3'd4 ||
                dut.main5_temperature_applied!=3'd5 ||
                main5_display[95:88]!=8'hff)
                $fatal(1,"custom adjust/status failed");
            force dut.lecture_active=1'b1;
            force dut.overview_enable_video=1'b0;
            force dut.lecture_display_frame_slot=3'd0;
            force dut.transition_active=1'b0;
            force dut.zoom_2x=1'b1;
            timeout=0;
            while (!dut.display_zoom_2x && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (!dut.display_zoom_2x) $fatal(1,"zoom entry timeout");
            repeat(6) @(negedge clk_50m);
            send_remote(8'h15,{8'd0,8'd0,8'd2,8'd0,16'sd3,16'sd2},8'd0);
            timeout=0;
            while ((dut.display_pan_x!=16'sd3 || dut.display_pan_y!=16'sd2) &&
                   timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (dut.display_pan_x!=16'sd3 || dut.display_pan_y!=16'sd2 ||
                dut.transition_active)
                $fatal(1,"viewport did not move without transition");
            send_remote(8'h15,{8'd1,8'd0,8'd2,8'd0,16'sd0,16'sd0},8'd5);
            // Pausing freezes the timeline, not direct viewport commits.
            force dut.lecture_paused=1'b1;
            repeat(6) @(negedge clk_50m);
            send_remote(8'h15,{8'd0,8'd0,8'd2,8'd0,16'sd2,-16'sd2},8'd0);
            timeout=0;
            while ((dut.display_pan_x!=2 || dut.display_pan_y!=-2) && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"paused pan commit blocked");
            release dut.zoom_2x;
            @(negedge clk_50m); force dut.key_press_pulse=4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            timeout=0;
            while(dut.display_zoom_2x!=2 && timeout<100000)begin
                @(negedge clk_50m);timeout=timeout+1;
            end
            if(timeout==100000 || dut.display_pan_x!=0 || dut.display_pan_y!=0)
                $fatal(1,"paused half scale commit blocked or zoom did not override pan");
            repeat(6)@(negedge clk_50m);
            if(dut.main5_display[55:48]!==8'd0)$fatal(1,"half scale status encoding");
            send_remote(8'h15,{8'd0,8'd0,8'd0,8'd0,16'sd0,16'sd2},8'd5);
            send_remote(8'h15,{8'd0,8'd0,8'd0,8'd1,32'd0},8'd0);
            @(negedge clk_50m); force dut.key_press_pulse=4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            timeout=0;
            while (dut.display_zoom_2x && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"paused zoom commit blocked");
            repeat(6) @(negedge clk_50m);
            send_remote(8'h15,{8'd0,8'd0,8'd1,8'd0,-16'sd3,16'sd3},8'd0);
            timeout=0;
            while ((dut.display_pan_x!=-3 || dut.display_pan_y!=3) && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"1x pan commit blocked");
            repeat(12) @(negedge clk_50m);
            if(dut.main5_display[31:16]!==16'hfffd || dut.main5_display[15:0]!==16'd3)
                $fatal(1,"signed pan report lost sign extension");
            force dut.transition_active=1'b1;
            repeat(6) @(negedge clk_50m);
            send_remote(8'h13,{8'd0,8'd1,16'd0,32'd0},8'd4);
            force dut.transition_active=1'b0;
            repeat(6) @(negedge clk_50m);
            send_remote(8'h13,{8'd0,8'd1,16'd0,32'd0},8'd0);
            timeout=0;
            while (dut.main5_preset_applied!=0 && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"preset after BUSY/custom did not recover");
            // Accepted in 50 MHz domain, but transition starts before video commit.
            // Even when paused, retire with BUSY rather than hold the request forever.
            force dut.video_frame_tick=1'b0;
            fork
                send_remote(8'h13,{8'd1,8'd1,16'd0,32'd0},8'd4);
                begin
                    wait(dut.main5_request_busy);
                    force dut.transition_active=1'b1;
                    repeat(8) @(negedge clk_50m);
                    release dut.video_frame_tick;
                end
            join
            if(dut.main5_request_busy || dut.main5_preset_applied!=0)
                $fatal(1,"transition race left busy or applied a rejected preset");
            force dut.transition_active=1'b0;
            repeat(6) @(negedge clk_50m);
            send_remote(8'h13,{8'd1,8'd1,16'd0,32'd0},8'd0);
            // Recovery must commit overview geometry with the overview cache,
            // even when the lecture was paused with a displaced 2x viewport.
            @(negedge clk_50m); force dut.key_press_pulse=4'b0001;
            @(negedge clk_50m); release dut.key_press_pulse;
            timeout=0;
            while (!dut.display_zoom_2x && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"recovery test zoom entry timeout");
            send_remote(8'h15,{8'd0,8'd0,8'd2,8'd0,16'sd2,-16'sd2},8'd0);
            timeout=0;
            while (dut.display_pan_x!=2 && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"recovery test pan entry timeout");
            force dut.overview_cache_ready=1'b1;
            force dut.sd_init_done=1'b0;
            @(negedge clk_50m); force dut.key_press_pulse=4'b1000;
            @(negedge clk_50m); release dut.key_press_pulse;
            release dut.lecture_active;
            release dut.lecture_paused;
            release dut.overview_enable_video;
            timeout=0;
            while (dut.display_media_index!=5 && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000 || dut.display_zoom_2x ||
                dut.display_pan_x!=0 || dut.display_pan_y!=0)
                $fatal(1,"KEY4 overview retained lecture zoom/pan");
            repeat(12) @(negedge clk_50m);
            if (dut.main5_zoom_ff2 || dut.main5_display[31:0]!=0)
                $fatal(1,"KEY4 telemetry retained lecture viewport");
            release dut.sd_init_done;
            timeout=0;
            while (dut.recovery_busy && timeout<100000) begin
                @(negedge clk_50m); timeout=timeout+1;
            end
            if (timeout==100000) $fatal(1,"KEY4 recovery did not finish");
            repeat(3000) @(negedge clk_50m);
            if (dut.display_media_index!=5 || dut.display_zoom_2x ||
                dut.display_pan_x!=0 || dut.display_pan_y!=0 || dut.switch_pending)
                $fatal(1,"stale lecture viewport returned after recovery");
            if (dut.g_linebuf_scaler.u_linebuf_scaler.active_zoom_2x ||
                dut.g_linebuf_scaler.u_linebuf_scaler.active_source_x_start!=0 ||
                dut.g_linebuf_scaler.u_linebuf_scaler.active_source_y_start!=0)
                $fatal(1,"overview line buffer retained stale source geometry");
            $display("PASS MAIN5 KEY4 restores 1x centered overview from paused 2x pan");
            sw[3]=1'b1;
            repeat(6) @(negedge clk_50m);
            send_remote(8'h13,{8'd0,8'd1,16'd0,32'd0},8'd4);
            $display("PASS MAIN5 remote preset/adjust/viewport/priority");
            $finish;
        end

        if (MAIN5_CONTROLS_TEST) begin
            if (!dut.overview_osd_visible || !dut.normal_waveform_visible)
                $fatal(1, "MAIN5 controls did not default visible");
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0100;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.overview_osd_visible || !dut.normal_waveform_visible ||
                dut.brightness_level != 0 || dut.contrast_level != 0)
                $fatal(1, "overview KEY3 did not exclusively hide overview OSD");
            force dut.lecture_active = 1'b1;
            force dut.overview_enable_video = 1'b0;
            repeat (10) @(negedge clk_50m);
            force dut.key_press_pulse = 4'b0100;
            @(negedge clk_50m); release dut.key_press_pulse;
            repeat (10) @(negedge clk_50m);
            if (dut.overview_osd_visible || !dut.normal_waveform_visible || dut.playback_speed_video!=1)
                $fatal(1, "lecture KEY3 did not select 2x while retaining waveform");
            force dut.lecture_paused = 1'b1;
            force dut.key_press_pulse = 4'b0100;
            @(negedge clk_50m); release dut.key_press_pulse;
            repeat (10) @(negedge clk_50m);
            if (dut.playback_speed_video!=2 || dut.main5_heartbeat[18:17]!=2)
                $fatal(1, "paused KEY3 did not select/report 3x");
            // Exercise all existing masks at 3x at their closing/opening
            // boundaries: the larger step must land on, never cross, the end.
            force dut.video_run=1;
            force dut.video_frame_tick=1;
            force dut.switch_pending=0;
            force dut.lecture_paused_ff2=0;
            force dut.transition_pace=0;
            for(mode_check=0;mode_check<8;mode_check=mode_check+1) begin
                force dut.transition_mode=mode_check[2:0];
                force dut.fade_out_active=1;
                @(negedge dut.video_clk);
                dut.transition_progress=(mode_check==5 ? 64 : mode_check==7 ? 32 : 16)-1;
                dut.fade_level=1;
                @(posedge dut.video_clk);#1;
                if(mode_check==0 ? dut.fade_level!=0 :
                   dut.transition_progress!=(mode_check==5 ? 64 : mode_check==7 ? 32 : 16))
                    $fatal(1,"3x closing transition overshot mode=%d",mode_check);
                force dut.fade_out_active=0;
                @(negedge dut.video_clk);
                dut.transition_progress=(mode_check==5 ? 128 : mode_check==7 ? 64 : 32)-1;
                dut.fade_level=15;
                @(posedge dut.video_clk);#1;
                if(mode_check==0 ? dut.fade_level!=16 :
                   dut.transition_progress!=(mode_check==5 ? 128 : mode_check==7 ? 64 : 32))
                    $fatal(1,"3x opening transition overshot mode=%d",mode_check);
            end
            release dut.video_run;release dut.video_frame_tick;release dut.switch_pending;
            release dut.lecture_paused_ff2;release dut.transition_mode;release dut.fade_out_active;
            release dut.transition_pace;
            @(negedge clk_50m);
            force dut.key_press_pulse = 4'b0100;
            @(negedge clk_50m); release dut.key_press_pulse;
            repeat (10) @(negedge clk_50m);
            if (dut.playback_speed_video!=0) $fatal(1,"KEY3 speed wrap failed");
            release dut.lecture_paused;
            release dut.lecture_active;
            release dut.overview_enable_video;
            repeat (10) @(negedge clk_50m);
            if(dut.playback_speed_video!=0) $fatal(1,"overview retained speed");
            $display("PASS MAIN5 KEY3 overview OSD / lecture 1x-2x-3x, paused selection and telemetry");
            $finish;
        end

        if (MAIN3_RECOVERY_TEST) begin
            @(negedge clk_50m); force dut.key_press_pulse = 4'b1000;
            @(negedge clk_50m); release dut.key_press_pulse;
            if (dut.recovery_state != 3'd1 || !dut.u_sd_card_top.rst)
                $fatal(1, "KEY4 did not start SD recovery");
            @(negedge clk_50m);
            if (dut.recovery_state != 3'd2 || dut.client_rst_n)
                $fatal(1, "client reset did not follow writer drain");
            force dut.key_press_pulse = 4'b1000;
            repeat (4) @(negedge clk_50m);
            release dut.key_press_pulse;
            if (dut.recovery_state != 3'd2 || !dut.video_rst_n || !dut.mem_rst_n)
                $fatal(1, "repeated KEY4 interrupted recovery or video/SDRAM");
            repeat (20) @(negedge clk_50m);
            if (dut.recovery_state != 3'd0 || !dut.client_rst_n)
                $fatal(1, "recovery did not finish after SD init");
            force dut.sd_init_done = 1'b0;
            force dut.key_press_pulse = 4'b1000;
            @(negedge clk_50m); release dut.key_press_pulse;
            repeat (20) @(negedge clk_50m);
            if (dut.recovery_state != 3'd3)
                $fatal(1, "recovery did not wait for SD init");
            force dut.recovery_wait_count = 27'd100_000_000;
            @(negedge clk_50m); release dut.recovery_wait_count;
            if (dut.recovery_state != 3'd4)
                $fatal(1, "SD init timeout did not enter fault state");
            release dut.sd_init_done;
            force dut.key_press_pulse = 4'b1000;
            @(negedge clk_50m); release dut.key_press_pulse;
            repeat (20) @(negedge clk_50m);
            if (dut.recovery_state != 3'd0)
                $fatal(1, "KEY4 did not retry after SD init failure");
            $display("PASS MAIN3 KEY4 drain/reset/reinit, timeout retry, repeated-key isolation");
            $finish;
        end

        if (MAIN4_EMERGENCY_TEST) begin
            sw[3] = 1'b1;
            repeat (30) @(negedge clk_50m);
            if (!dut.emergency_active_50m || !dut.recovery_busy ||
                dut.recovery_state != 3'd3)
                $fatal(1, "SW4 did not hold safe recovery during emergency state=%0d",
                       dut.recovery_state);
            while (!dut.emergency_video_ff2) @(negedge clk_50m);
            while (!dut.video_frame_tick) @(negedge clk_50m);
            @(negedge clk_50m);
            if (!dut.emergency_video_active)
                $fatal(1, "emergency video was not published at the next frame boundary");
            force dut.recovery_wait_count = 27'd100_000_000;
            @(negedge clk_50m); release dut.recovery_wait_count;
            @(negedge clk_50m);
            if (dut.recovery_state != 3'd3 || dut.recovery_wait_count != 0)
                $fatal(1, "held SW4 incorrectly entered SD timeout fault");
            force dut.sd_init_done = 1'b0;
            sw[3] = 1'b0;
            while (dut.emergency_video_ff2) @(negedge clk_50m);
            while (!dut.video_frame_tick) @(negedge clk_50m);
            @(negedge clk_50m);
            repeat (20) @(negedge clk_50m);
            if (dut.recovery_state != 3'd3 || !dut.recovery_busy)
                $fatal(1, "SW4 clear did not wait for delayed SD init");
            release dut.sd_init_done;
            timeout = 0;
            while (dut.recovery_busy && timeout < 5000) begin
                @(negedge clk_50m); timeout = timeout + 1;
            end
            if (dut.recovery_busy || dut.emergency_video_active ||
                dut.recovery_state != 3'd0)
                $fatal(1, "SW4 clear did not return to clean normal state");
            $display("PASS MAIN4 SW4 priority, held recovery, frame-boundary clear");
            $finish;
        end

        if (SD_ABORT_TEST) begin
            timeout = 0;
            while (dut.sd_read_active && timeout < 1000) begin
                @(negedge clk_50m); timeout = timeout + 1;
            end
            if (dut.sd_read_active) $fatal(1, "SD arbiter did not become idle");
            @(negedge clk_50m);
            force dut.image_sd_sec_read = 1'b0;
            force dut.subtitle_sd_sec_read = 1'b0;
            force dut.audio_sd_sec_read = 1'b1;
            force dut.sd_sec_read_data_valid = 1'b0;
            force dut.sd_sec_read_end = 1'b0;
            repeat (2) @(negedge clk_50m);
            if (!dut.sd_read_active || !dut.sd_read_audio_owner)
                $fatal(1, "SD arbiter did not grant audio read");
            force dut.audio_sd_sec_read = 1'b0;
            @(negedge clk_50m);
            if (!dut.sd_read_abandoned)
                $fatal(1, "aborted sector was not marked stale");
            force dut.audio_sd_sec_read = 1'b1;
            force dut.sd_sec_read_data_valid = 1'b1;
            #1;
            if (dut.audio_sd_sec_read_data_valid)
                $fatal(1, "stale sector data entered restarted audio reader");
            force dut.sd_sec_read_end = 1'b1;
            #1;
            if (dut.audio_sd_sec_read_end)
                $fatal(1, "stale sector end entered restarted audio reader");
            @(negedge clk_50m);
            force dut.sd_sec_read_data_valid = 1'b0;
            force dut.sd_sec_read_end = 1'b0;
            repeat (2) @(negedge clk_50m);
            if (!dut.sd_read_active || dut.sd_read_abandoned)
                $fatal(1, "new read did not start after aborted sector drained");
            force dut.sd_sec_read_data_valid = 1'b1;
            force dut.sd_sec_read_end = 1'b1;
            #1;
            if (!dut.audio_sd_sec_read_data_valid || !dut.audio_sd_sec_read_end)
                $fatal(1, "new sector was not delivered to audio reader");
            @(negedge clk_50m);
            force dut.audio_sd_sec_read = 1'b0;
            force dut.sd_sec_read_data_valid = 1'b0;
            force dut.sd_sec_read_end = 1'b0;
            force dut.subtitle_sd_sec_read = 1'b1;
            repeat (2) @(negedge clk_50m);
            if (!dut.sd_read_active || !dut.sd_read_subtitle_owner)
                $fatal(1, "subtitle read was not granted");
            force dut.subtitle_sd_sec_read = 1'b0;
            @(negedge clk_50m);
            if (!dut.sd_read_abandoned)
                $fatal(1, "aborted subtitle sector was not marked stale");
            force dut.subtitle_sd_sec_read = 1'b1;
            force dut.audio_sd_sec_read = 1'b1;
            force dut.sd_sec_read_data_valid = 1'b1;
            force dut.sd_sec_read_end = 1'b1;
            #1;
            if (dut.subtitle_sd_sec_read_data_valid || dut.subtitle_sd_sec_read_end)
                $fatal(1, "stale subtitle sector entered restarted reader");
            @(negedge clk_50m);
            force dut.sd_sec_read_data_valid = 1'b0;
            force dut.sd_sec_read_end = 1'b0;
            repeat (2) @(negedge clk_50m);
            if (!dut.sd_read_active || !dut.sd_read_audio_owner ||
                dut.sd_read_abandoned)
                $fatal(1, "audio request did not follow aborted subtitle sector");
            $display("PASS aborted audio/subtitle sectors isolated; next requests accepted");
            $finish;
        end

        if (OUTPUT_ROUTE_TEST) begin
            // The 720p v26 output registers must consume the subtitle result,
            // not bypass it with the pre-subtitle OSD RGB bus.
            force dut.video_subtitle_hs = 1'b1;
            force dut.video_subtitle_vs = 1'b1;
            force dut.video_subtitle_de = 1'b1;
            force dut.video_subtitle_rgb = 24'hdffcff;
            repeat (4) @(posedge clk_50m);
            #1;
            if (!dut.video_de_out || dut.video_rgb_out !== 24'hdffcff) begin
                $display("FAIL v26 subtitle output route de=%b rgb=%h",
                         dut.video_de_out, dut.video_rgb_out);
                $finish;
            end
            $display("PASS v26 subtitle output route");
            release dut.video_subtitle_hs;
            release dut.video_subtitle_vs;
            release dut.video_subtitle_de;
            release dut.video_subtitle_rgb;
            $finish;
        end

        if (PHASE1_TEST) begin
            if (dut.osd_panel_enable !== 1'b1 || dut.auto_mode !== 1'b0) begin
                $display("FAIL phase1 initial panel=%b auto=%b", dut.osd_panel_enable, dut.auto_mode);
                $finish;
            end
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0001;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.osd_panel_enable !== 1'b0) begin
                $display("FAIL phase1 KEY1 panel off=%b", dut.osd_panel_enable);
                $finish;
            end
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0001;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.osd_panel_enable !== 1'b1) begin
                $display("FAIL phase1 KEY1 panel on=%b", dut.osd_panel_enable);
                $finish;
            end
            sw = 4'b0011;
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.audio_paused !== 1'b1) begin
                $display("FAIL phase1 audio KEY2 pause=%b", dut.audio_paused);
                $finish;
            end
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0100;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.audio_track_index !== 2'd3 || dut.audio_paused !== 1'b0) begin
                $display("FAIL phase1 audio KEY3 prev=%0d paused=%b", dut.audio_track_index, dut.audio_paused);
                $finish;
            end
            if (dut.audio_switch_reset_count == 0)
                $fatal(1, "phase1 track switch did not immediately mute/reset audio");
            @(negedge clk_50m); force dut.key_press_pulse = 4'b1000;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.audio_track_index !== 2'd0) begin
                $display("FAIL phase1 audio KEY4 next=%0d", dut.audio_track_index);
                $finish;
            end
            sw = 4'b0000;
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.audio_track_index !== 2'd0 || dut.audio_paused !== 1'b0) begin
                $display("FAIL phase1 non-audio changed track=%0d paused=%b", dut.audio_track_index, dut.audio_paused);
                $finish;
            end
            $display("PASS phase1 controls and audio isolation");
            $finish;
        end

        if (PHASE2_TEST) begin
            if (dut.manual_image_index !== 4'd0 || dut.zoom_2x !== 1'b0 ||
                dut.picture_style !== 2'd0) begin
                $display("FAIL phase2 initial img=%0d zoom=%b style=%0d",
                         dut.manual_image_index, dut.zoom_2x, dut.picture_style);
                $finish;
            end
            sw = 4'b0010;
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.manual_image_index !== 4'd1) begin
                $display("FAIL phase2 KEY2 image=%0d", dut.manual_image_index);
                $finish;
            end
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0100;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.zoom_2x !== 1'b1) begin
                $display("FAIL phase2 KEY3 zoom=%b", dut.zoom_2x);
                $finish;
            end
            @(negedge clk_50m); force dut.key_press_pulse = 4'b1000;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.picture_style !== 2'd1) begin
                $display("FAIL phase2 KEY4 style=%0d", dut.picture_style);
                $finish;
            end
            sw = 4'b0000;
            @(negedge clk_50m); force dut.key_press_pulse = 4'b1110;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.zoom_2x !== 1'b1 || dut.picture_style !== 2'd1 ||
                dut.audio_paused !== 1'b0 ||
                dut.audio_track_index !== 2'd0) begin
                $display("FAIL phase2 non-detail changed detail/audio state");
                $finish;
            end
            $display("PASS phase2 detail controls and audio isolation");
            $finish;
        end

        if (PHASE3_TEST) begin
            timeout = 0;
            while (timeout < 30000 && dut.frame_valid != 5'b11111) begin
                @(posedge clk_50m);
                timeout = timeout + 1;
            end
            if (dut.frame_valid != 5'b11111)
                $fatal(1, "phase3 five-frame preload timeout");

            for (primitive_id = 0; primitive_id < 4; primitive_id = primitive_id + 1) begin
                sw = {primitive_id[1:0], 2'b10};
                repeat (4) @(posedge clk_50m);
                old_display_media = dut.display_media_index;

                @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
                @(posedge clk_50m); #1; release dut.key_press_pulse;
                timeout = 0;
                while (timeout < 20 && !dut.switch_pending) begin
                    @(posedge clk_50m); timeout = timeout + 1;
                end
                if (!dut.switch_pending || !dut.transition_active ||
                    dut.transition_mode != primitive_id[2:0])
                    $fatal(1, "phase3 start failed primitive=%0d mode=%0d active=%b",
                           primitive_id, dut.transition_mode, dut.transition_active);

                force dut.video_vblank_start = 1'b0;
                for (step = 0; step < 16; step = step + 1) begin
                    @(negedge clk_50m); force dut.video_frame_tick = 1'b1;
                    @(posedge clk_50m); #1; release dut.video_frame_tick;
                end
                if (!dut.transition_midpoint_ready || !dut.fade_out_active)
                    $fatal(1, "phase3 midpoint failed primitive=%0d progress=%0d fade=%0d",
                           primitive_id, dut.transition_progress, dut.fade_level);

                @(negedge clk_50m); force dut.video_vblank_start = 1'b1;
                @(posedge clk_50m); #1;
                release dut.video_vblank_start;
                if (dut.video_run || dut.display_media_index == old_display_media)
                    $fatal(1, "phase3 unsafe source switch primitive=%0d old=%0d new=%0d run=%b",
                           primitive_id, old_display_media, dut.display_media_index,
                           dut.video_run);

                @(negedge clk_50m);
                force dut.linebuf_frame_ready = 1'b1;
                force dut.video_frame_start = 1'b1;
                @(posedge clk_50m); #1;
                release dut.linebuf_frame_ready;
                release dut.video_frame_start;
                if (!dut.video_run)
                    $fatal(1, "phase3 source resume failed primitive=%0d", primitive_id);

                for (step = 0; step < 16; step = step + 1) begin
                    @(negedge clk_50m); force dut.video_frame_tick = 1'b1;
                    @(posedge clk_50m); #1; release dut.video_frame_tick;
                end
                if (dut.transition_active)
                    $fatal(1, "phase3 done failed primitive=%0d progress=%0d fade=%0d",
                           primitive_id, dut.transition_progress, dut.fade_level);
            end

            // Detail zoom restarts the source mapping at a frame boundary,
            // but it is not a scene transition and must never animate.
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0100;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            timeout = 0;
            while (timeout < 20 && !dut.switch_pending) begin
                @(posedge clk_50m); timeout = timeout + 1;
            end
            if (!dut.direct_switch_pending || dut.transition_active ||
                dut.fade_out_active)
                $fatal(1, "phase3 zoom incorrectly entered transition");
            @(negedge clk_50m); force dut.video_vblank_start = 1'b1;
            @(posedge clk_50m); #1; release dut.video_vblank_start;
            if (dut.video_run || !dut.display_zoom_2x)
                $fatal(1, "phase3 direct zoom boundary switch failed");

            $display("PASS phase3 four primitives and direct non-transition zoom");
            $finish;
        end

        if (PHASE4_TEST) begin
            timeout = 0;
            while (timeout < 30000 && dut.frame_valid != 5'b11111) begin
                @(posedge clk_50m);
                timeout = timeout + 1;
            end
            if (dut.frame_valid != 5'b11111)
                $fatal(1, "phase4 five-frame preload timeout");

            // Slideshow uses the upper switches as the direct primitive
            // selector. Start at 1x with Curtain selected.
            sw = 4'b1001;
            repeat (4) @(posedge clk_50m);
            if (!dut.auto_mode || dut.auto_speed_level != 2'd1 ||
                dut.slideshow_paused)
                $fatal(1, "phase4 slideshow entry failed");

            @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.auto_speed_level != 2'd2)
                $fatal(1, "phase4 KEY2 did not select 2x speed");

            old_display_media = dut.auto_image_index;
            @(negedge clk_50m); force dut.key_press_pulse = 4'b1000;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.auto_speed_level != 2'd2 || dut.slideshow_paused ||
                dut.auto_image_index != old_display_media)
                $fatal(1, "phase4 KEY4 was not a no-op");

            @(negedge clk_50m); force dut.key_press_pulse = 4'b0100;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (!dut.slideshow_paused)
                $fatal(1, "phase4 KEY3 did not pause");
            repeat (40) @(posedge clk_50m);
            if (dut.auto_image_index != old_display_media)
                $fatal(1, "phase4 paused slideshow advanced");

            @(negedge clk_50m); force dut.key_press_pulse = 4'b0100;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            timeout = 0;
            while (timeout < 40 && dut.auto_image_index == old_display_media) begin
                @(posedge clk_50m); timeout = timeout + 1;
            end
            if (dut.auto_image_index == old_display_media)
                $fatal(1, "phase4 resumed slideshow did not advance");
            repeat (6) @(posedge clk_50m);
            if (dut.transition_mode != 3'd2)
                $fatal(1, "phase4 slideshow did not use direct Curtain primitive");

            // 2x -> 4x -> 0.5x -> 1x.
            repeat (3) begin
                @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
                @(posedge clk_50m); #1; release dut.key_press_pulse;
            end
            if (dut.auto_speed_level != 2'd1)
                $fatal(1, "phase4 four-speed cycle failed");

            // Product Show remains a placeholder; KEY2 is its Phase-4 Theme
            // test entry and must advance both image and context.
            sw = 4'b1100;
            repeat (4) @(posedge clk_50m);
            old_display_media = dut.manual_image_index;
            @(negedge clk_50m); force dut.key_press_pulse = 4'b0010;
            @(posedge clk_50m); #1; release dut.key_press_pulse;
            if (dut.manual_image_index == old_display_media ||
                dut.transition_context != 2'd1 || dut.demo_transition_step != 2'd1)
                $fatal(1, "phase4 Product Show Theme test entry failed");

            $display("PASS phase4 slideshow controls and Theme test entry");
            $finish;
        end

        if (PRELOAD_TEST) begin
            // The loader and writer stubs finish each transaction quickly,
            // but the RTL under test must still issue two independent loads,
            // publish only frame 0, and switch to the resident frame 1
            // without starting another load.
            timeout = 0;
            while (timeout < 10000 && dut.frame_valid != 2'b11) begin
                @(posedge clk_50m);
                timeout = timeout + 1;
            end
            if (dut.frame_valid != 2'b11 || dut.published_frame_index != 1'b0 ||
                dut.published_media_index != 4'd0 || dut.load_active) begin
                $display("FAIL preload setup valid=%b published=%b/%0d active=%b",
                         dut.frame_valid, dut.published_frame_index,
                         dut.published_media_index, dut.load_active);
                $finish;
            end
            preload_ready_toggle = dut.frame_ready_toggle;
            @(negedge clk_50m);
            force dut.key_press_pulse = 4'b0010;
            @(posedge clk_50m);
            @(negedge clk_50m);
            release dut.key_press_pulse;
            timeout = 0;
            while (timeout < 10000 && dut.display_frame_index != 1'b1) begin
                @(posedge clk_50m);
                timeout = timeout + 1;
            end
            if (dut.display_frame_index != 1'b1 || dut.display_media_index != 4'd1 ||
                dut.frame_ready_toggle != preload_ready_toggle || dut.load_active) begin
                $display("FAIL preload switch display=%b/%0d ready=%b->%b active=%b manual=%0d select=%b/%b pending=%b run=%b",
                         dut.display_frame_index, dut.display_media_index,
                         preload_ready_toggle, dut.frame_ready_toggle, dut.load_active,
                         dut.manual_image_index, dut.preload_select_frame_index,
                         dut.preload_select_ff2, dut.switch_pending, dut.video_run);
                $finish;
            end
            $display("PASS preload both-valid then frame-boundary KEY2 switch");
            $finish;
        end

        if (MULTI5_TEST) begin
            timeout = 0;
            while (timeout < 30000 && dut.frame_valid != 5'b11111) begin
                @(posedge clk_50m);
                timeout = timeout + 1;
            end
            if (dut.frame_valid != 5'b11111 || dut.published_media_index != 4'd0 ||
                dut.load_active) begin
                $display("FAIL multi5 preload setup valid=%b published=%0d active=%b",
                         dut.frame_valid, dut.published_media_index, dut.load_active);
                $finish;
            end
            preload_ready_toggle = dut.frame_ready_toggle;
            for (target_index = 1; target_index < 5; target_index = target_index + 1) begin
                @(negedge clk_50m);
                force dut.key_press_pulse = 4'b0010;
                @(posedge clk_50m);
                @(negedge clk_50m);
                release dut.key_press_pulse;
                timeout = 0;
                while (timeout < 100 && dut.preload_select_media_index != target_index) begin
                    @(posedge clk_50m);
                    timeout = timeout + 1;
                end
                if (dut.preload_select_media_index != target_index || dut.load_active ||
                    dut.frame_ready_toggle != preload_ready_toggle) begin
                    $display("FAIL multi5 cache select target=%0d select=%0d valid=%b ready=%b->%b active=%b",
                             target_index, dut.preload_select_media_index, dut.frame_valid,
                             preload_ready_toggle, dut.frame_ready_toggle, dut.load_active);
                    $finish;
                end
            end
            $display("PASS five cached frames selected without TF reload");
            $finish;
        end

        if (LONG_CHECK) begin
            timeout = 0;
            while (long_frames < 3 && timeout < 60000) begin
                @(posedge clk_50m);
                timeout = timeout + 1;
            end
            if (long_frames < 3 || long_mismatch != 0) begin
                $display("FAIL top-chain long frames=%0d mismatches=%0d",
                         long_frames, long_mismatch);
                $finish;
            end
            $display("PASS top-chain long frames=%0d active_mismatch=%0d",
                     long_frames, long_mismatch);

            // Verify that the source/video chain can restart cleanly after
            // warm board resets, not only after the initial power-on reset.
            if (RESET_STRESS) begin
                repeat (3) begin
                    key_n[0] = 1'b0;
                    #40;
                    key_n[0] = 1'b1;
                    timeout = 0;
                    while (timeout < 100000 && !dut.video_run) begin
                        @(posedge clk_50m);
                        timeout = timeout + 1;
                    end
                    if (!dut.video_run) begin
                        $display("FAIL top-chain warm-reset video_run timeout");
                        $finish;
                    end
                end
                $display("PASS top-chain warm resets=3");
            end
            $finish;
        end

        // Allow at least one complete small raster after startup.
        repeat (400) @(posedge clk_50m);
        if (active_samples == 0 || nonzero_samples == 0) begin
            $display("FAIL top-chain no RGB active=%0d nonzero=%0d run=%b ready=%b",
                     active_samples, nonzero_samples, dut.video_run,
                     dut.linebuf_frame_ready);
            $finish;
        end
        $display("PASS top-chain active=%0d nonzero=%0d first_nonzero=%0d",
                 active_samples, nonzero_samples, first_nonzero_cycle);
        $finish;
    end
endmodule

// Clock models keep the integration test independent of vendor PLL macros.
module system_clock_pll(input wire refclk, input wire reset,
                output wire clk0_out, output wire clk1_out,
                output wire clk2_out, output wire locked);
    reg lock_enable=1'b1;
    assign locked=lock_enable && !reset;
    assign clk0_out = refclk;
    assign clk1_out = refclk;
    assign clk2_out = refclk;
endmodule

module hdmi_pixel_clock_pll(input wire refclk, input wire reset,
                     output wire clk0_out, output wire clk1_out, output wire locked);
    reg lock_enable=1'b1;
    assign locked=lock_enable && !reset;
    assign clk0_out = refclk;
    assign clk1_out = refclk;
endmodule

`ifndef REAL_MEDIA
module sd_card_top (
    input wire clk, input wire rst,
    output wire SD_nCS, output wire SD_DCLK, output wire SD_MOSI,
    input wire SD_MISO, output wire sd_init_done,
    input wire sd_sec_read, input wire [31:0] sd_sec_read_addr,
    output wire [7:0] sd_sec_read_data,
    output wire sd_sec_read_data_valid, output wire sd_sec_read_end,
    input wire sd_sec_write, input wire [31:0] sd_sec_write_addr,
    input wire [7:0] sd_sec_write_data,
    output wire sd_sec_write_data_req, output wire sd_sec_write_end
);
    assign SD_nCS = 1'b1;
    assign SD_DCLK = 1'b0;
    assign SD_MOSI = 1'b0;
    assign sd_init_done = 1'b1;
    assign sd_sec_read_data = 8'd0;
    assign sd_sec_read_data_valid = 1'b0;
    assign sd_sec_read_end = 1'b0;
    assign sd_sec_write_data_req = 1'b0;
    assign sd_sec_write_end = 1'b0;
endmodule
`endif

`ifdef REAL_MEDIA
// Direct sector-level FAT32 model for the real loader.  The BMP is 24x18,
// bottom-up, 24-bit and uncompressed; the SPI pins are intentionally ignored.
module sd_card_top (
    input wire clk, input wire rst,
    output wire SD_nCS, output wire SD_DCLK, output wire SD_MOSI,
    input wire SD_MISO, output reg sd_init_done,
    input wire sd_sec_read, input wire [31:0] sd_sec_read_addr,
    output reg [7:0] sd_sec_read_data,
    output reg sd_sec_read_data_valid, output reg sd_sec_read_end,
    input wire sd_sec_write, input wire [31:0] sd_sec_write_addr,
    input wire [7:0] sd_sec_write_data,
    output wire sd_sec_write_data_req, output wire sd_sec_write_end
);
    localparam integer VOLUME_LBA = 2048;
    localparam integer FAT_LBA = VOLUME_LBA + 32;
    localparam integer DATA_LBA = VOLUME_LBA + 34;
    localparam integer ROOT_LBA = DATA_LBA;
    localparam integer FIRST_CLUSTER = 3;
    localparam integer FILE_LBA = DATA_LBA + 64;
    localparam integer FILE_BYTES = 54 + 24 * 18 * 3;
    localparam integer FILE_SECTORS = 1;
    reg [7:0] disk [0:1100000];
    integer i, x, y, off;
    integer sector_addr;

    assign SD_nCS = 1'b1;
    assign SD_DCLK = 1'b0;
    assign SD_MOSI = 1'b0;
    assign sd_sec_write_data_req = 1'b0;
    assign sd_sec_write_end = 1'b0;

    task put_byte;
        input integer lba;
        input integer offset;
        input [7:0] value;
        begin disk[lba * 512 + offset] = value; end
    endtask
    task put_le32;
        input integer lba;
        input integer offset;
        input [31:0] value;
        begin
            put_byte(lba, offset, value[7:0]);
            put_byte(lba, offset + 1, value[15:8]);
            put_byte(lba, offset + 2, value[23:16]);
            put_byte(lba, offset + 3, value[31:24]);
        end
    endtask

    initial begin
        for (i = 0; i <= 1100000; i = i + 1)
            disk[i] = 8'd0;
        put_le32(0, 454, VOLUME_LBA);
        put_byte(VOLUME_LBA, 11, 8'h00);
        put_byte(VOLUME_LBA, 12, 8'h02);
        put_byte(VOLUME_LBA, 13, 8'd64);
        put_byte(VOLUME_LBA, 14, 8'd32);
        put_byte(VOLUME_LBA, 16, 8'd2);
        put_le32(VOLUME_LBA, 36, 32'd1);
        put_le32(VOLUME_LBA, 44, 32'd2);

        put_byte(ROOT_LBA, 0, "I"); put_byte(ROOT_LBA, 1, "M");
        put_byte(ROOT_LBA, 2, "A"); put_byte(ROOT_LBA, 3, "G");
        put_byte(ROOT_LBA, 4, "E"); put_byte(ROOT_LBA, 5, "0");
        put_byte(ROOT_LBA, 6, " "); put_byte(ROOT_LBA, 7, " ");
        put_byte(ROOT_LBA, 8, "B"); put_byte(ROOT_LBA, 9, "M");
        put_byte(ROOT_LBA, 10, "P"); put_byte(ROOT_LBA, 11, 8'h20);
        put_le32(ROOT_LBA, 26, FIRST_CLUSTER);
        put_le32(ROOT_LBA, 28, FILE_BYTES);
        put_le32(FAT_LBA, FIRST_CLUSTER * 4, 32'h0fffffff);

        put_byte(FILE_LBA, 0, "B"); put_byte(FILE_LBA, 1, "M");
        put_le32(FILE_LBA, 2, FILE_BYTES);
        put_le32(FILE_LBA, 10, 32'd54);
        put_le32(FILE_LBA, 14, 32'd40);
        put_le32(FILE_LBA, 18, 32'd24);
        put_le32(FILE_LBA, 22, 32'd18);
        put_byte(FILE_LBA, 26, 8'd1);
        put_byte(FILE_LBA, 28, 8'd24);
        put_le32(FILE_LBA, 30, 32'd0);
        for (y = 0; y < 18; y = y + 1) begin
            for (x = 0; x < 24; x = x + 1) begin
                off = 54 + y * 72 + x * 3;
                put_byte(FILE_LBA, off + 0, x[7:0]);
                put_byte(FILE_LBA, off + 1, y[7:0]);
                put_byte(FILE_LBA, off + 2, (x + y) & 8'hff);
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            sd_init_done <= 1'b0;
        else
            sd_init_done <= 1'b1;
    end

    always @(posedge sd_sec_read) begin
        sector_addr = sd_sec_read_addr;
        for (i = 0; i < 512; i = i + 1) begin
            @(negedge clk);
            sd_sec_read_data <= disk[sector_addr * 512 + i];
            sd_sec_read_data_valid <= 1'b1;
        end
        @(negedge clk);
        sd_sec_read_data_valid <= 1'b0;
        sd_sec_read_end <= 1'b1;
        @(negedge clk);
        sd_sec_read_end <= 1'b0;
    end

    initial begin
        sd_sec_read_data = 8'd0;
        sd_sec_read_data_valid = 1'b0;
        sd_sec_read_end = 1'b0;
    end
endmodule
`endif

`ifndef REAL_MEDIA
module fat32_image_loader #(
    parameter integer IMAGE_WIDTH = 160,
    parameter integer IMAGE_HEIGHT = 120,
    parameter integer IMAGE_ADDR_BITS = 15,
    parameter integer MULTI_IMAGE_BMP = 0,
    parameter integer BMP_MAX_WIDTH = 1024,
    parameter integer BMP_MAX_HEIGHT = 768,
    parameter integer ADAPTIVE_BMP = 0,
    parameter [15:0] ADAPTIVE_BACKGROUND_RGB565 = 16'h0000,
    parameter integer RESOURCE_OPT_CONSTANT_MULT = 0,
    parameter ADAPTIVE_RAM_IMPLEMENT = "9K"
) (
    input wire clk, input wire rst_n, input wire load_start,
    input wire [3:0] image_file_index,
    input wire museum_detail_mode, input wire [2:0] museum_artifact_index,
    input wire [1:0] museum_detail_index, input wire bmp_mode,
    input wire sequence_mode, input wire sd_init_done,
    output wire sd_sec_read, output wire [31:0] sd_sec_read_addr,
    input wire [7:0] sd_sec_read_data,
    input wire sd_sec_read_data_valid, input wire sd_sec_read_end,
    input wire image_continue,
    output wire image_wr_en, output wire [IMAGE_ADDR_BITS-1:0] image_wr_addr,
    output wire [15:0] image_wr_data, output wire [10:0] image_wr_row,
    output wire [10:0] image_wr_col, output reg busy,
    output reg load_done, output reg load_error, output reg [3:0] status_code,
    output wire [3:0] error_stage,
    output reg [15:0] bmp_source_width, output reg [15:0] bmp_source_height,
    output wire benchmark_file_phase, output wire benchmark_payload_sector
);

assign benchmark_file_phase = busy;
assign benchmark_payload_sector = sd_sec_read;
    reg [5:0] count;
    assign sd_sec_read = 1'b0;
    assign sd_sec_read_addr = 32'd0;
    assign image_wr_en = 1'b0;
    assign image_wr_addr = {IMAGE_ADDR_BITS{1'b0}};
    assign image_wr_data = 16'd0;
    assign image_wr_row = 11'd0;
    assign image_wr_col = 11'd0;
    assign error_stage = 4'd0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            load_done <= 1'b0;
            load_error <= 1'b0;
            status_code <= 4'd0;
            bmp_source_width <= IMAGE_WIDTH;
            bmp_source_height <= IMAGE_HEIGHT;
            count <= 6'd0;
        end else if (load_start) begin
            busy <= 1'b1;
            load_done <= 1'b0;
            load_error <= 1'b0;
            status_code <= 4'd1;
            count <= 6'd0;
        end else if (busy) begin
            if (count == 6'd15) begin
                busy <= 1'b0;
                load_done <= 1'b1;
                status_code <= 4'h8;
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule
`endif

`ifndef REAL_MEDIA
module bmp_row_buffer #(
    parameter integer WIDTH = 640, parameter integer HEIGHT = 480,
    parameter integer COL_BITS = 10, parameter integer ROW_BITS = 9
) (
    input wire clk, input wire rst_n, input wire in_valid,
    input wire [ROW_BITS-1:0] in_row, input wire [COL_BITS-1:0] in_col,
    input wire [15:0] in_pixel, output wire overflow,
    output wire out_valid, output wire [ROW_BITS-1:0] out_row,
    output wire [15:0] out_pixel, output wire out_last,
    input wire out_ready, output wire out_row_done,
    output wire input_continue
);
    assign overflow = 1'b0;
    assign out_valid = 1'b0;
    assign out_row = {ROW_BITS{1'b0}};
    assign out_pixel = 16'd0;
    assign out_last = 1'b0;
    assign out_row_done = 1'b0;
    assign input_continue = 1'b0;
endmodule
`endif

`ifndef REAL_MEDIA
module bmp_sdram_row_writer #(
    parameter integer WIDTH = 640, parameter integer HEIGHT = 480,
    parameter integer ROW_BITS = 9, parameter integer ADDR_BITS = 21,
    parameter integer WORDS_PER_ROW = WIDTH / 2,
    parameter integer BURST_WORDS = WORDS_PER_ROW,
    parameter integer OVERVIEW_ENABLE = 0,
    parameter integer OVERVIEW_BRAM = 0,
    parameter integer OVERVIEW_FRAME_COUNT = 5,
    parameter integer OVERVIEW_PANEL_WIDTH = WIDTH / 5,
    parameter integer ENABLE_ABORT = 0,
    parameter integer OVERVIEW_CROP_X0_0 = 0,
    parameter integer OVERVIEW_CROP_X0_1 = 0,
    parameter integer OVERVIEW_CROP_X0_2 = 0,
    parameter integer OVERVIEW_CROP_X0_3 = 0,
    parameter integer OVERVIEW_CROP_X0_4 = 0
) (
    input wire clk, input wire rst_n, input wire start,
    input wire row_valid, input wire [ROW_BITS-1:0] row_index,
    input wire [15:0] row_pixel, input wire row_last, output wire row_ready,
    input wire [ADDR_BITS-1:0] frame_base_addr,
    input wire [ADDR_BITS-1:0] overview_base_addr,
    input wire [3:0] overview_frame_index,
    output wire write_req, input wire write_req_ack, output wire write_en,
    output wire [31:0] write_data, output wire [ADDR_BITS-1:0] write_base_addr,
    output wire [ADDR_BITS-1:0] write_len, input wire write_fifo_full,
    input wire write_finish, input wire abort, output wire abort_done,
    output reg frame_done, output wire error
);
    reg [5:0] count;
    assign row_ready = 1'b1;
    assign write_req = 1'b0;
    assign write_en = 1'b0;
    assign write_data = 32'd0;
    assign write_base_addr = {ADDR_BITS{1'b0}};
    assign write_len = {ADDR_BITS{1'b0}};
    assign error = 1'b0;
    assign abort_done = 1'b1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_done <= 1'b0;
            count <= 6'd0;
        end else if (start) begin
            frame_done <= 1'b0;
            count <= 6'd0;
        end else if (!frame_done) begin
            if (count == 6'd20)
                frame_done <= 1'b1;
            else
                count <= count + 1'b1;
        end
    end
endmodule
`endif

`ifdef STUB_STORE
// Deterministic two-frame store.  Each source word carries two nonzero RGB565
// values; read_data is deliberately registered to model the real FIFO return.
module anlogic_frame_store #(
    parameter integer MEM_DATA_BITS = 32, parameter integer ADDR_BITS = 21,
    parameter integer BURST_BITS = 9, parameter integer BURST_SIZE = 256,
    parameter integer WRITE_BURST_SIZE = BURST_SIZE,
    parameter integer READ_BURST_SIZE = BURST_SIZE,
    parameter READ_FIFO_OUTREG = "NOREG", parameter integer READ_LOOP = 1,
    parameter READ_SKIP_ROW_WORDS = 0
) (
    input wire mem_clk, input wire mem_clk_sft, input wire rst_n,
    output wire init_done, output wire init_ref_valid, output wire mem_busy,
    input wire write_clk, input wire write_req, output wire write_req_ack,
    output wire write_finish, output wire write_fifo_full,
    input wire [ADDR_BITS-1:0] write_base_addr,
    input wire [ADDR_BITS-1:0] write_len, input wire write_en,
    input wire [MEM_DATA_BITS-1:0] write_data,
    input wire read_clk, input wire read_req, output reg read_req_ack,
    input wire read_skip_third_row,
    output wire read_finish, output wire read_fifo_valid,
    output reg read_fifo_empty, input wire [ADDR_BITS-1:0] read_base_addr,
    input wire [ADDR_BITS-1:0] read_len, input wire read_en,
    output reg [MEM_DATA_BITS-1:0] read_data
);
    reg read_req_d;
    reg [ADDR_BITS-1:0] rd_word;
    function [15:0] pixel;
        input integer p;
        begin
            pixel = 16'h8000 | (p & 16'h07ff);
        end
    endfunction
    assign init_done = 1'b1;
    assign init_ref_valid = 1'b1;
    assign mem_busy = 1'b0;
    assign write_req_ack = 1'b0;
    assign write_finish = 1'b0;
    assign write_fifo_full = 1'b0;
    assign read_finish = 1'b0;
    assign read_fifo_valid = !read_fifo_empty;
    always @(posedge read_clk or negedge rst_n) begin
        if (!rst_n) begin
            read_req_d <= 1'b0;
            read_req_ack <= 1'b0;
            read_fifo_empty <= 1'b1;
            read_data <= 32'd0;
            rd_word <= {ADDR_BITS{1'b0}};
        end else begin
            read_req_d <= read_req;
            read_req_ack <= read_req && !read_req_d;
            if (read_req && !read_req_d) begin
                read_fifo_empty <= 1'b0;
                rd_word <= {ADDR_BITS{1'b0}};
            end
            if (read_en) begin
                read_data <= {pixel(rd_word * 2), pixel(rd_word * 2 + 1)};
                // The production reader loops at read_len.  Mirror that
                // boundary here so a multi-frame timing run starts every
                // frame at source pixel zero instead of carrying the prior
                // frame's word offset into the next raster.
                if (read_len != 0 && rd_word >= read_len - 1'b1)
                    rd_word <= {ADDR_BITS{1'b0}};
                else
                    rd_word <= rd_word + 1'b1;
                read_fifo_empty <= 1'b0;
            end
        end
    end
endmodule
`else
// The real anlogic_frame_store wrapper is compiled by the real-store .do file.
// Keeping this stub conditional lets the same integration test exercise both
// the pixel chain in isolation and the official frame FIFO path.
`endif

`ifndef STUB_STORE
// Lightweight SDRAM controller model for the official frame FIFO wrapper.
// App reads return a deterministic RGB565 pair one memory clock later.
module sdram (
    input wire Clk, input wire Clk_sft, input wire Rst,
    output reg Sdr_init_done, output reg Sdr_init_ref_vld,
    output reg Sdr_busy, input wire App_wr_en,
    input wire [20:0] App_wr_addr, input wire [3:0] App_wr_dm,
    input wire [31:0] App_wr_din, input wire App_rd_en,
    input wire [20:0] App_rd_addr, output reg Sdr_rd_en,
    output reg [31:0] Sdr_rd_dout
);
    // Store application writes, then return the same words on reads.  The
    // earlier model synthesized a read-only pattern and could not expose a
    // frame write/read ordering or address fault.
    reg [31:0] memory [0:2097151];
    integer wr_debug_count = 0;
    integer rd_debug_count = 0;
    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            Sdr_init_done <= 1'b0;
            Sdr_init_ref_vld <= 1'b0;
            Sdr_busy <= 1'b0;
            Sdr_rd_en <= 1'b0;
            Sdr_rd_dout <= 32'd0;
        end else begin
            Sdr_init_done <= 1'b1;
            Sdr_init_ref_vld <= 1'b1;
            Sdr_busy <= 1'b0;
            Sdr_rd_en <= App_rd_en;
            if (App_wr_en)
                memory[App_wr_addr] <= App_wr_din;
            if (App_wr_en && wr_debug_count < 24) begin
                $display("SDWR t=%0t addr=%0d data=%h dm=%h", $time,
                         App_wr_addr, App_wr_din, App_wr_dm);
                wr_debug_count = wr_debug_count + 1;
            end
            if (App_rd_en)
                Sdr_rd_dout <= memory[App_rd_addr];
            if (App_rd_en && rd_debug_count < 24) begin
                $display("SDRD t=%0t addr=%0d data=%h", $time,
                         App_rd_addr, memory[App_rd_addr]);
                rd_debug_count = rd_debug_count + 1;
            end
        end
    end
endmodule
`endif

module key_debounce #(
    parameter integer DEBOUNCE_BITS = 19
) (
    input wire clk, input wire rst_n, input wire [3:0] key_n,
    output wire [3:0] key_level_n, output wire [3:0] key_press_pulse,
    output wire [3:0] key_release_pulse
);
    assign key_level_n = key_n;
    assign key_press_pulse = 4'd0;
    assign key_release_pulse = 4'd0;
endmodule

module seg_hex_display (
    input wire clk, input wire rst_n, input wire [15:0] value,
    output wire [7:0] seg_data, output wire [7:0] seg_sel
);
    assign seg_data = 8'hff;
    assign seg_sel = 8'hff;
endmodule

module osd_status_1280_pipe (
    input wire clk, input wire rst_n, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    input wire [3:0] image_index, input wire auto_mode,
    input wire [1:0] brightness_level, input wire [1:0] contrast_level,
    input wire [1:0] audio_track_index, input wire [1:0] mode,
    input wire panel_enable, input wire zoom_2x, input wire [1:0] picture_style,
    input wire [1:0] auto_speed_level, input wire slideshow_paused,
    input wire [1:0] transition_theme, input wire [1:0] transition_context,
    input wire [15:0] source_width_bcd, input wire [15:0] source_height_bcd,
    output wire [23:0] rgb_o
);
    assign rgb_o = rgb_i;
endmodule

module osd_status_rgb888 (
    input wire de, input wire [9:0] x, input wire [9:0] y,
    input wire [23:0] rgb_in, input wire enable, input wire [3:0] image_index,
    input wire auto_mode, input wire [1:0] brightness_level,
    input wire [1:0] contrast_level, input wire [15:0] source_width_bcd,
    input wire [15:0] source_height_bcd, output wire [23:0] rgb_out
);
    assign rgb_out = rgb_in;
endmodule

module osd_status (
    input wire de, input wire [9:0] x, input wire [9:0] y,
    input wire [11:0] rgb_in, input wire enable, input wire [3:0] image_index,
    input wire auto_mode, input wire [1:0] brightness_level,
    input wire [1:0] contrast_level, output wire [11:0] rgb_out
);
    assign rgb_out = rgb_in;
endmodule

module hdmi_tx #(
    parameter FAMILY = "EG4"
) (
    input wire PXLCLK_I, input wire PXLCLK_5X_I, input wire RST_N,
    input wire VGA_HS, input wire VGA_VS, input wire VGA_DE,
    input wire [23:0] VGA_RGB, output wire HDMI_CLK_P,
    output wire HDMI_D2_P, output wire HDMI_D1_P, output wire HDMI_D0_P
);
    assign HDMI_CLK_P = PXLCLK_I;
    assign HDMI_D2_P = VGA_DE && |VGA_RGB;
    assign HDMI_D1_P = VGA_HS;
    assign HDMI_D0_P = VGA_VS;
endmodule

`default_nettype wire
