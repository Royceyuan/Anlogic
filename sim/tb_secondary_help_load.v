`timescale 1ns/1ps
// The real top-level media scheduler; only physical SD/SDRAM/PLL/HDMI are
// bounded stubs. FAT pixels and the real primitives are tested separately.
module tb_secondary_help_load;
reg clk=0, rst_n=0, done=0, frame_done=0, failed=0;
always #5 clk=~clk;
reg [3:0] switches=0;
reg cmd_valid=0;
reg [7:0] cmd_type=0, artifact=0;
reg test_pass=0;
integer loads=0, help_loads=0;
reg [2:0] sync_previous=3'b110;
reg [2:0] sync_expected=3'b110;
integer sync_checks=0;
reg [2:0] scan_input=3'b110;
reg [23:0] scan_rgb_input=0, rgb_previous=0, rgb_expected=0;
reg monitor_rgb=0;
reg pixel_valid=0;
reg [10:0] pixel_row=0, pixel_col=0;
reg [15:0] pixel_data=0;
integer scan_step;
top_v66 #(.VIDEO_W(1280),.VIDEO_H(720),.SOURCE_W(1280),.SOURCE_H(720),
    .VIDEO_MODE_1280(1),.ADAPTIVE_BMP(1),.MULTI_IMAGE_BMP(1),
    .MULTI_FRAME_PRELOAD(1),.VIDEO_FRAME_COUNT(5),.SECONDARY_STREAMING(1),
    .ENABLE_SECONDARY(1),.SECONDARY_HELP(1),.ENABLE_FADE(1),
    .RESOURCE_OPT_CONSTANT_MULT(1)) dut (
    .clk_50m(clk),.key_n(4'hf),.sw(4'b0001),.sd_miso(1'b1),.uart_rxd(1'b1),
    .led(),.seg_data(),.seg_sel(),.sd_clk(),.sd_mosi(),.sd_cs_n(),
    .vga_hs(),.vga_vs(),.vga_d(),.hdmi1_clk_p(),.hdmi1_d2_p(),
    .hdmi1_d1_p(),.hdmi1_d0_p(),.hdmi1_ddc_scl(),.hdmi1_ddc_sda(),.uart_txd(),
    .secondary_cmd_valid(cmd_valid),.secondary_cmd_type(cmd_type),
    .secondary_cmd_artifact_id(artifact),.secondary_cmd_confirmed(1'b0),
    .secondary_cmd_mode(8'd1),.secondary_cmd_lecture_phase(8'hff),
    .secondary_cmd_lecture_reason(8'd0),.secondary_cmd_emergency_id(16'd0),
    .secondary_cmd_route_id(8'd0),.secondary_cmd_emergency_active(1'b0),
    .secondary_cmd_result(),
    .secondary_manual_mode(1'b0),.secondary_manual_next(1'b0),
    .secondary_help_switches(switches),.secondary_eng_enable(1'b0),
    .secondary_eng_link(1'b0),.secondary_eng_heartbeat(128'h0100ff00000000000000000000000000),
    .secondary_eng_display(96'd0),.secondary_eng_diagnostic(128'd0),.secondary_eng_result(8'd0)
);
always @(negedge clk) if(dut.image_load_start) begin
    loads=loads+1;
    if(dut.u_fat32_image_loader.IMAGE_WIDTH!=160 ||
       dut.u_fat32_image_loader.IMAGE_HEIGHT!=90 ||
       dut.u_fat32_image_loader.HIRES_WIDTH!=1280 ||
       dut.u_fat32_image_loader.HIRES_HEIGHT!=720 ||
       !dut.u_fat32_image_loader.FIXED_BMP)
        $fatal(1,"native help must use fixed dual-size loader");
    if(dut.load_image_index==7) begin
        help_loads=help_loads+1;
        if(dut.writer_start || dut.loader_file_index!=11 || !dut.row_input_continue)
            $fatal(1,"help must bypass SDRAM writer and select IMAGEB");
        if(dut.u_fat32_image_loader.hires_frame)
            $fatal(1,"help target must be native 160x90");
    end else if(!dut.u_fat32_image_loader.hires_frame) begin
        $fatal(1,"ordinary media target must remain native 1280x720");
    end
end
// The new glyph stage and RGB pass-through have one extra cycle; all scan
// signals must follow the same two-cycle delay from the original output.
always @(posedge clk) begin
    if(!rst_n) begin sync_previous=3'b110; sync_checks=0; end
    else begin
        sync_expected=sync_previous;
        sync_previous={dut.video_hs_out,dut.video_vs_out,dut.video_de_out};
        rgb_expected=rgb_previous;
        rgb_previous=dut.g_secondary_overlay.engineering_rgb;
        sync_checks=sync_checks+1;
        #1;
        if(sync_checks>2 && {dut.secondary_hs_out,dut.secondary_vs_out,dut.secondary_de_out} !== sync_expected)
            $fatal(1,"help pipeline changed RGB/sync alignment");
        if(monitor_rgb && sync_checks>2 && dut.secondary_rgb_out !== (sync_expected[0] ? rgb_expected : 24'd0))
            $fatal(1,"normal RGB and scan delay diverged");
    end
end
task finish;
    begin
        repeat(4) @(negedge clk);
        done=1; frame_done=1;
        wait(!dut.load_active);
        @(negedge clk); done=0; frame_done=0;
    end
endtask
task boot;
    begin
        rst_n=0; done=0; frame_done=0; failed=0;
        repeat(5) @(negedge clk); rst_n=1;
        wait(dut.image_load_start); #1;
        if(dut.load_image_index!=0) $fatal(1,"normal initial image changed");
        finish();
        wait(dut.image_load_start); #1;
        if(dut.load_image_index!=6 || dut.loader_file_index!=10)
            $fatal(1,"emergency image must load before optional help");
        finish();
        wait(dut.image_load_start); #1;
        if(dut.load_image_index!=7) $fatal(1,"help load was not scheduled");
    end
endtask
initial begin
    force dut.mem_clk=clk; force dut.video_clk=clk; force dut.video_clk_5x=clk;
    force dut.mem_rst_n=rst_n; force dut.write_rst_n=rst_n; force dut.video_rst_n=rst_n;
    force dut.image_load_done=done; force dut.frame_done=frame_done;
    force dut.image_load_error=failed; force dut.writer_error=1'b0;
    force dut.image_wr_en=pixel_valid;
    force dut.image_wr_row=pixel_row; force dut.image_wr_col=pixel_col;
    force dut.image_wr_data=pixel_data;
    force dut.image_source_width=16'd160; force dut.image_source_height=16'd90;
    force dut.stream_load_request=1'b0;
    boot();
    @(negedge clk); pixel_row=89; pixel_col=159; pixel_data=16'habcd; pixel_valid=1;
    @(negedge clk); pixel_valid=0;
    if(dut.g_secondary_overlay.g_help_page.u_help.backdrop[14399]!==16'habcd ||
       dut.g_secondary_overlay.g_help_page.u_help.write_address!=14399)
        $fatal(1,"native help final pixel did not reach 8x background cache");
    finish();
    if(!dut.secondary_help_valid || dut.frame_valid!=5'b00001 || !dut.secondary_emergency_valid)
        $fatal(1,"help completion corrupted normal/emergency cache");
    repeat(3) begin switches=8; repeat(5) @(negedge clk); switches=0; repeat(5) @(negedge clk); end
    if(help_loads!=1 || loads!=3) $fatal(1,"SW4 caused media reload");
    // A missing or invalid optional background must relinquish the loader.
    boot(); repeat(4) @(negedge clk); failed=1;
    wait(!dut.load_active); @(negedge clk); failed=0;
    if(!dut.secondary_help_error || dut.secondary_help_valid || dut.secondary_help_load_request)
        $fatal(1,"failed optional help repeated or published");
    cmd_type=8'h10; artifact=2; cmd_valid=1;
    @(negedge clk); cmd_valid=0;
    wait(dut.image_load_start); #1;
    if(dut.load_image_index!=5 || dut.loader_file_index!=7 || !dut.writer_start)
        $fatal(1,"info loading did not resume after help error");
    finish();
    if(!dut.secondary_info_valid || dut.secondary_info_cached_artifact!=2)
        $fatal(1,"info completion failed");
    force dut.video_hs_out=scan_input[2];
    force dut.video_vs_out=scan_input[1];
    force dut.video_de_out=scan_input[0];
    force dut.g_secondary_overlay.engineering_rgb=scan_rgb_input;
    for(scan_step=0;scan_step<48;scan_step=scan_step+1) begin
        @(negedge clk); scan_input=scan_step[2:0]; scan_rgb_input=24'h123400+scan_step;
        if(scan_step==3) monitor_rgb=1;
    end
    @(negedge clk); monitor_rgb=0;
    test_pass=1;
    $display("PASS real top media scheduler: fixed dual-size target, native help cache, help once, no SDRAM write, emergency priority, SW4 isolation, missing help recovery, scan delay aligned");
    $finish;
end
initial begin #50000; $fatal(1,"integration timeout"); end
endmodule
