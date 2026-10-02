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
    if(dut.load_image_index==7) begin
        help_loads=help_loads+1;
        if(dut.writer_start || dut.loader_file_index!=11 || !dut.row_input_continue)
            $fatal(1,"help must bypass SDRAM writer and select IMAGEB");
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
    force dut.image_wr_en=1'b0;
    force dut.image_source_width=16'd160; force dut.image_source_height=16'd90;
    force dut.stream_load_request=1'b0;
    boot(); finish();
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
    test_pass=1;
    $display("PASS real top media scheduler: help once, no SDRAM write, emergency priority, SW4 isolation, missing help recovery");
    $finish;
end
initial begin #50000; $fatal(1,"integration timeout"); end
endmodule
