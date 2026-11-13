`timescale 1ns / 1ps
module tb_museum_overview_slot_reuse;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, confirm=0, audio_tick=0, key_return=0, busy=0;
    reg manual_set=0, manual_value=0, manual_image_set=0;
    reg [1:0] manual_image=0;
    reg [2:0] selected=0, displayed=5;
    reg [4:0] home_valid=5'b11111;
    reg accept=0, complete=0;
    wire request, active, ready, final_full, waiting, manual_ready;
    wire [1:0] phase, request_detail;
    wire [2:0] slot, request_slot, request_artifact;
    museum_lecture_controller #(.CLOCK_HZ(2),.REUSE_OVERVIEW_SLOTS(1),.ENABLE_MANUAL(1)) dut (
        .clk(clk),.rst_n(rst_n),.enable(1'b1),.overview_ready(1'b1),
        .confirm_pulse(confirm),.key_pause(1'b0),.key_return(key_return),
        .manual_set(manual_set),.manual_value(manual_value),
        .manual_image_set(manual_image_set),.manual_image(manual_image),.manual_cache_ready(manual_ready),
        .selected_index(selected),.preload_valid(!active),.preload_index(selected),
        .audio_prepared(1'b1),.full_home_valid(home_valid),
        .overview_displayed(displayed==5),.loading_allowed(1'b1),
        .audio_frame_pulse(audio_tick),.audio_total_frames(32'd8),
        .audio_stream_done(1'b0),.audio_drained(1'b0),.scene_timing_valid(1'b1),
        .scene_cut1(32'd1),.scene_cut2(32'd2),.scene_cut3(32'd3),.scene_cut4(32'd4),
        .displayed_frame_slot(displayed),.display_transition_busy(busy),
        .load_request(request),.load_accept(accept),.load_complete(complete),.load_error(1'b0),
        .load_slot(request_detail),.load_frame_slot(request_slot),.load_artifact_index(request_artifact),
        .cache_ready(ready),.lecture_active(active),.display_slot(phase),
        .display_frame_slot(slot),.final_full_active(final_full),.waiting_for_image(waiting)
    );
    task tick_audio;
        begin
            @(negedge clk); audio_tick=1;
            @(negedge clk); audio_tick=0;
        end
    endtask
    task choose_manual_image;
        input [1:0] image;
        begin
            @(negedge clk); manual_image=image; manual_image_set=1;
            @(negedge clk); manual_image_set=0;
        end
    endtask
    task finish_load;
        input [1:0] detail;
        input [2:0] target, artifact;
        begin
            wait (request);
            if (request_slot!==target || request_detail!==detail || request_artifact!==artifact)
                $fatal(1,"request detail=%d slot=%d artifact=%d",request_detail,request_slot,request_artifact);
            if (target==displayed || (active && target==selected))
                $fatal(1,"write to displayed or selected slot");
            @(negedge clk); accept=1; home_valid[target]=0;
            @(negedge clk); accept=0; complete=1; home_valid[target]=(detail==0);
            @(negedge clk); complete=0;
        end
    endtask
    integer id;
    reg [2:0] d1,d2,d3;
    initial begin
        for (id=0;id<5;id=id+1) begin
            @(negedge clk); rst_n=0; displayed=5; home_valid=31;
            selected=id;
            @(negedge clk); rst_n=1;
            wait (ready);
            repeat (3) @(negedge clk);
            if (request) $fatal(1,"detail preload started before KEY2");
            confirm=1;
            @(negedge clk); confirm=0;
            if (!active || slot!=id || !waiting) $fatal(1,"KEY2 did not open cached full view");
            displayed=id;
            d1=id==0 ? 1 : 0;
            d2=id<=1 ? 2 : 1;
            d3=id<=2 ? 3 : 2;
            finish_load(1,d1,id);
            tick_audio;
            @(negedge clk);
            if (slot!=d1 || phase!=1 || !waiting) $fatal(1,"bad first detail or late-image guard");
            displayed=d1;
            finish_load(2,d2,id);
            tick_audio;
            @(negedge clk);
            displayed=d2; busy=1;
            finish_load(3,d3,id);
            repeat(4) @(negedge clk);
            if (request) $fatal(1,"restored a slot before the transition finished");
            busy=0;
            finish_load(0,d1,d1);
            tick_audio;
            @(negedge clk);
            displayed=d3;
            finish_load(0,d2,d2);
            tick_audio;
            @(negedge clk);
            if (slot!=id || !final_full) $fatal(1,"ending full view did not reuse opening slot");
            displayed=id;
            finish_load(0,d3,d3);
            if (home_valid!=31) $fatal(1,"overview homes were not all restored");
            key_return=1;
            @(negedge clk); key_return=0;
            wait (!active);
        end
        @(negedge clk); displayed=5; selected=2; home_valid=5'b10101;
        wait (request);
        finish_load(0,1,1);
        selected=3;
        wait (!ready);
        wait (request);
        finish_load(0,3,3);
        wait (ready);
        confirm=1;
        @(negedge clk); confirm=0;
        if (!active || slot!=3) $fatal(1,"immediate next selection entered before its full view");
        @(negedge clk); rst_n=0; displayed=5; selected=1; home_valid=31;
        @(negedge clk); rst_n=1; manual_value=1; manual_set=1;
        @(negedge clk); manual_set=0;
        wait (ready);
        repeat (2) @(negedge clk);
        if (request) $fatal(1,"manual detail load started before KEY2");
        confirm=1;
        @(negedge clk); confirm=0;
        if (!active || slot!=1) $fatal(1,"manual did not enter on cached full view");
        displayed=1;
        choose_manual_image(1);
        if (phase!=0) $fatal(1,"manual selected incomplete detail");
        finish_load(1,0,1);
        choose_manual_image(3);
        if (phase!=0) $fatal(1,"manual skipped detail 1");
        choose_manual_image(1);
        if (phase!=1 || slot!=0) $fatal(1,"manual did not show detail 1");
        displayed=0;
        finish_load(2,2,1);
        choose_manual_image(2);
        if (phase!=2 || slot!=2) $fatal(1,"manual did not show detail 2");
        displayed=2; busy=1;
        finish_load(3,3,1);
        repeat (2) @(negedge clk);
        if (request) $fatal(1,"manual overwrote detail 1 during transition");
        busy=0;
        finish_load(0,0,0);
        choose_manual_image(3);
        if (phase!=3 || slot!=3) $fatal(1,"manual did not show detail 3");
        displayed=3;
        finish_load(0,2,2);
        choose_manual_image(0);
        if (phase!=0 || slot!=1 || !final_full || !active)
            $fatal(1,"manual did not reuse its original slot as final full view");
        busy=1;
        repeat (3) @(negedge clk);
        if (request || !active) $fatal(1,"manual exited or restored before final full view was visible");
        displayed=1; busy=0;
        wait (!active);
        @(negedge clk); displayed=5;
        finish_load(0,3,3);
        if (home_valid!=31) $fatal(1,"manual left overview slots unrestored");
        $display("PASS five automatic artifacts and manual forward-only slot reuse with automatic return");
        $finish;
    end
    initial begin #20000; $fatal(1,"slot reuse timeout"); end
endmodule
