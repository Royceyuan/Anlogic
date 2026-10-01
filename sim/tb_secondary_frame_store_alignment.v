`timescale 1ns/1ps
// Exercise the real wrapper, transaction controllers and async FIFOs against
// the one-clock early data timing established by D126/D127 hardware evidence.
module tb_secondary_frame_store_alignment;
    parameter integer EXPECT_ERROR = 0;
    reg mem_clk=0, read_clk=0, rst_n=0, read_req=0, consume=0, phase=0;
    reg [20:0] read_base=0;
    wire init_done, ack, valid, empty;
    wire [31:0] data;
    integer received=0, requested=0, errors=0, first_word=-1;
    reg [31:0] first_actual=0;
    reg checks_passed=0;
    always #10 mem_clk=~mem_clk;
    always #6.666667 read_clk=~read_clk;
    wire pop=consume && phase && !empty && requested<1280;
    anlogic_frame_store #(.BURST_SIZE(128), .WRITE_BURST_SIZE(16),
        .READ_BURST_SIZE(128), .READ_LOOP(1)) dut (
        .mem_clk(mem_clk), .mem_clk_sft(mem_clk), .rst_n(rst_n),
        .init_done(init_done), .init_ref_valid(), .mem_busy(),
        .write_clk(mem_clk), .write_req(1'b0), .write_req_ack(),
        .write_finish(), .write_fifo_full(), .write_base_addr(21'd0),
        .write_len(21'd16), .write_en(1'b0), .write_data(32'd0),
        .read_clk(read_clk), .read_req(read_req), .read_req_ack(ack),
        .read_finish(), .read_fifo_valid(valid), .read_fifo_empty(empty),
        .read_base_addr(read_base), .read_len(21'd640),
        .read_en(pop), .read_data(data));
    always @(posedge read_clk) begin
        if(!rst_n) begin phase<=0; requested<=0; received<=0; end
        else begin
            phase<=!phase;
            if(pop) requested<=requested+1;
            if(valid) begin
                if(data !== (32'hA5000000+read_base+(received%640))) begin
                    errors=errors+1;
                    if(first_word<0) begin first_word=received; first_actual=data; end
                end
                if(received==0 || received==639 || received==640 || received==1279)
                    $display("BOUNDARY base=%0d word=%0d actual=%h",read_base,received,data);
                received<=received+1;
            end
        end
    end
    task read_two_frames;
        input [20:0] base;
        begin
            consume=0; rst_n=0; read_req=0; read_base=base;
            repeat(10) @(negedge mem_clk);
            rst_n=1;
            wait(init_done);
            @(negedge mem_clk); read_req=1;
            wait(ack);
            @(negedge mem_clk); read_req=0;
            repeat(80) @(negedge read_clk);
            consume=1;
            wait(received==1280);
            @(negedge read_clk); consume=0;
            if(requested!=1280) $fatal(1,"request/return count requested=%0d received=%0d",requested,received);
            repeat(20) @(negedge read_clk);
            if(received!=1280) $fatal(1,"unexpected extra FIFO valid received=%0d",received);
        end
    endtask
    initial begin
        read_two_frames(21'd0);
        read_two_frames(21'd1024);
        if(EXPECT_ERROR) begin
            if(errors==0 || first_word!=0 || first_actual!=32'hA5000001)
                $fatal(1,"old wrapper did not reproduce shift: errors=%0d first=%0d actual=%h",errors,first_word,first_actual);
        end else if(errors!=0)
            $fatal(1,"wrapper mismatch: errors=%0d first=%0d actual=%h",errors,first_word,first_actual);
        checks_passed=1;
        $display("PASS wrapper regression EXPECT_ERROR=%0d errors=%0d frames=4 words=2560",EXPECT_ERROR,errors);
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout received=%0d requested=%0d",received,requested); end
endmodule

module sdram(input Clk, Clk_sft, Rst, output reg Sdr_init_done,
    output Sdr_init_ref_vld,Sdr_busy, input App_wr_en,
    input [20:0] App_wr_addr, input [3:0] App_wr_dm, input [31:0] App_wr_din,
    input App_rd_en, input [20:0] App_rd_addr,
    output reg Sdr_rd_en, output reg [31:0] Sdr_rd_dout);
    reg [5:0] rd_pipe=0, init_count=0;
    reg [20:0] addr_pipe [0:5];
    integer i;
    assign Sdr_init_ref_vld=0;
    assign Sdr_busy=0;
    always @(posedge Clk) begin
        if(Rst) begin
            Sdr_init_done<=0; init_count<=0; rd_pipe<=0;
            Sdr_rd_en<=0; Sdr_rd_dout<=0;
        end else begin
            if(init_count!=63) init_count<=init_count+1'b1;
            if(init_count==63) Sdr_init_done<=1;
            rd_pipe<={rd_pipe[4:0],App_rd_en};
            addr_pipe[0]<=App_rd_addr;
            for(i=1;i<6;i=i+1) addr_pipe[i]<=addr_pipe[i-1];
            Sdr_rd_en<=rd_pipe[5];
            if(rd_pipe[4]) Sdr_rd_dout<=32'hA5000000+addr_pipe[4];
        end
    end
endmodule
