`timescale 1ns / 1ps
module tb_museum_entry_sector_cache;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, allow_replay=0, audio_req=0, subtitle_req=0;
    reg audio_card_valid=0, subtitle_card_valid=0, audio_card_end=0, subtitle_card_end=0;
    reg [2:0] track=0;
    reg [3:0] audio_sector=0, subtitle_sector=0;
    reg [7:0] card_data=0;
    wire audio_hit, subtitle_hit, audio_valid, subtitle_valid, audio_end, subtitle_end;
    wire [7:0] audio_data, subtitle_data;
    museum_entry_sector_cache dut (
        .clk(clk),.rst_n(rst_n),.track(track),.audio_sector(audio_sector),
        .subtitle_sector(subtitle_sector),.audio_req(audio_req),.subtitle_req(subtitle_req),
        .card_data(card_data),.audio_card_valid(audio_card_valid),
        .subtitle_card_valid(subtitle_card_valid),.audio_card_end(audio_card_end),
        .subtitle_card_end(subtitle_card_end),.allow_replay(allow_replay),
        .audio_replay(audio_hit),.subtitle_replay(subtitle_hit),
        .audio_data(audio_data),.subtitle_data(subtitle_data),.audio_valid(audio_valid),
        .subtitle_valid(subtitle_valid),.audio_end(audio_end),.subtitle_end(subtitle_end)
    );
    function [7:0] sample;
        input integer id, sector, offset;
        begin sample = id*53 + sector*7 + offset/256*29 + offset; end
    endfunction
    task read_sector;
        input is_subtitle, replay;
        input integer id, sector, count;
        integer i, got;
        begin
            @(negedge clk);
            track=id; audio_sector=sector; subtitle_sector=sector;
            audio_req=!is_subtitle; subtitle_req=is_subtitle; allow_replay=replay;
            if (!replay) begin
                for(i=0;i<count;i=i+1) begin
                    card_data=sample(id,sector,i);
                    audio_card_valid=!is_subtitle; subtitle_card_valid=is_subtitle;
                    @(negedge clk);
                end
                audio_card_valid=0; subtitle_card_valid=0;
                audio_card_end=!is_subtitle; subtitle_card_end=is_subtitle;
                @(negedge clk); audio_card_end=0; subtitle_card_end=0;
            end else begin
                got=0;
                @(negedge clk);
                if (!(is_subtitle ? subtitle_hit : audio_hit))
                    $fatal(1,"cache miss track=%d sector=%d",id,sector);
                while (!(is_subtitle ? subtitle_end : audio_end)) begin
                    if (is_subtitle ? subtitle_valid : audio_valid) begin
                        if ((is_subtitle ? subtitle_data : audio_data)!==sample(id,sector,got))
                            $fatal(1,"bad replay track=%d sector=%d offset=%d",id,sector,got);
                        got=got+1;
                    end
                    @(negedge clk);
                end
                if (got!=512) $fatal(1,"replay count %d",got);
            end
            audio_req=0; subtitle_req=0; allow_replay=0;
            @(negedge clk);
        end
    endtask
    integer track_num, sector_num;
    initial begin
        repeat (2) @(negedge clk); rst_n=1;
        read_sector(1,0,4,13,511);
        @(negedge clk); subtitle_req=1; allow_replay=1;
        @(negedge clk); if (subtitle_hit) $fatal(1,"partial sector published");
        subtitle_req=0; allow_replay=0;
        for(track_num=0;track_num<5;track_num=track_num+1) begin
            for(sector_num=0;sector_num<3;sector_num=sector_num+1)
                read_sector(0,0,track_num,sector_num,512);
            for(sector_num=0;sector_num<14;sector_num=sector_num+1)
                read_sector(1,0,track_num,sector_num,512);
        end
        for(track_num=4;track_num>=0;track_num=track_num-1) begin
            for(sector_num=0;sector_num<3;sector_num=sector_num+1)
                read_sector(0,1,track_num,sector_num,512);
            for(sector_num=0;sector_num<14;sector_num=sector_num+1)
                read_sector(1,1,track_num,sector_num,512);
        end
        @(negedge clk); rst_n=0;
        @(negedge clk); rst_n=1; allow_replay=1; audio_req=1; audio_sector=0;
        @(negedge clk); if (audio_hit) $fatal(1,"hard reset retained old media");
        $display("PASS all five audio/subtitle prefixes, partial-sector rejection and hard-reset invalidation");
        $finish;
    end
    initial begin #2000000; $fatal(1,"sector cache timeout"); end
endmodule
