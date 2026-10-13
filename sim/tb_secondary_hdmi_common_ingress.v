`timescale 1ns/1fs
module tb_secondary_hdmi_common_ingress;
reg clk=0,uart_rxd=1,source_on=0;
always #10 clk=!clk;
reg [3:0] incoming=0;
wire [3:0] outgoing;
tri1 sda;
top_secondary_hdmi_museum dut(.clk_50m(clk),.uart_rxd(uart_rxd),.uart_txd(),
    .hdmi_a_clk_p(incoming[3]),.hdmi_a_d0_p(incoming[0]),.hdmi_a_d1_p(incoming[1]),.hdmi_a_d2_p(incoming[2]),
    .hdmi_a_scl(1'b1),.hdmi_a_sda(sda),.hdmi_a_hpd(),.hdmi_b_hpd(1'b1),
    .hdmi_b_clk_p(outgoing[3]),.hdmi_b_d0_p(outgoing[0]),.hdmi_b_d1_p(outgoing[1]),.hdmi_b_d2_p(outgoing[2]));
defparam dut.u_relay.u_clock.CLOCKS_PER_MS=500;
defparam dut.u_relay.u_monitor.GOOD_FRAMES=1;
defparam dut.g_carrier.u_carrier.SETTLE_CYCLES=64;
defparam dut.u_pc_video.BAUD_DIV=8;
defparam dut.u_relay.g_official_edid.u_slave.u2_iic.myedid_new_ram.inst.INIT_FILE="../vendor/official_hdmi_loop_edid/edid_1280720_75m_with_audio.mif";
function [9:0] ctrl;
input [1:0] n;
begin case(n)0:ctrl=10'h354;1:ctrl=10'h0ab;2:ctrl=10'h154;3:ctrl=10'h2ab;endcase end endfunction
function [7:0] crc8;
input [7:0] c,b;
reg [7:0] w;
integer n;
begin w=c^b;for(n=0;n<8;n=n+1) w=w[7]?(w<<1)^8'h07:w<<1;crc8=w;end endfunction
task uart_byte;
input [7:0] b;
integer n;
begin
    @(negedge clk);uart_rxd=0;repeat(8) @(negedge clk);
    for(n=0;n<8;n=n+1) begin uart_rxd=b[n];repeat(8) @(negedge clk);end
    uart_rxd=1;repeat(16) @(negedge clk);
end endtask
task command;
input [7:0] c,seq;
begin uart_byte(8'ha5);uart_byte(8'h5a);uart_byte(c);uart_byte(seq);uart_byte(crc8(crc8(crc8(crc8(0,8'ha5),8'h5a),c),seq));end endtask
integer sx,sy,bit_index;
integer first_line=720;
reg [29:0] word;
reg [1:0] sync_bits;
initial forever begin
    wait(source_on);
    for(sy=first_line;sy<750;sy=sy+1) for(sx=0;sx<1650;sx=sx+1) begin
        sync_bits={sy>=725&&sy<730,sx>=1390&&sx<1430};
        word={10'h354,10'h354,ctrl(sync_bits)};
        if(sx<1280&&sy<720) word={10'h133,10'h133,10'h28e};
        else if(sx>=1640&&sx<1648&&(sy<719||sy==749)) word={10'h354,10'h0ab,ctrl(sync_bits)};
        else if(sx>=1648&&(sy<719||sy==749)) word={10'h2cc,10'h133,10'h2cc};
        for(bit_index=0;bit_index<10;bit_index=bit_index+1) begin
            incoming=source_on?{bit_index<5,word[20+bit_index],word[10+bit_index],word[bit_index]}:0;
            // 13.34375ns pixel period (74.941MHz) is binary-exact. The vendor
            // PLL compares real-valued period deltas at 1e-8ns; a rounded
            // 13.33ns stimulus spuriously loses lock after 2^26ns simulation.
            // See tb_secondary_hdmi_pll_model; production clocks unchanged.
            #1.334375;
        end
    end
    first_line=0;
end
reg measuring=0,waiting_marker=0,test_pass=0,checking_fault_recovery=0;
integer clock_edges=0,visible_words=0;
real previous_clock=0;
reg [39:0] previous_words;
always @(outgoing[3]) if(measuring || checking_fault_recovery) begin
    if(clock_edges && ($realtime-previous_clock<6.65 || $realtime-previous_clock>6.69)) $fatal(1,"physical TMDS clock discontinuity");
    previous_clock=$realtime;clock_edges=clock_edges+1;
end
always @(dut.output_muted) if(measuring && dut.output_muted) $fatal(1,"authorization caused data IOL reset");
always @(negedge dut.external_ready)
    if(checking_fault_recovery) $fatal(1,"FIFO fault disturbed qualified HDMI input");
always @(negedge dut.pc_carrier)
    if(checking_fault_recovery) $fatal(1,"FIFO fault changed carrier selection");
always @(posedge dut.common_pclk) if(measuring) begin
    previous_words=dut.g_common.composed;
    if(dut.g_common.u_compositor.t[2]) begin
        if(dut.g_common.u_compositor.allow_pc && previous_words[29:0]=={10'h133,10'h133,10'h28e}) visible_words=visible_words+1;
    end
end
initial begin
    #2000000;source_on=1;
    wait(dut.input_available && !dut.output_muted);
    if(!dut.pc_carrier || dut.external_selected) $fatal(1,"input clock qualified but native preview not retained");
    $display("PASS real IOL capture, alignment, async buffer and genlocked native preview qualify through production top");
    #1000;measuring=1;
    command(1,1);wait(dut.external_selected);#1000000;
    if(visible_words<1000 || clock_edges<1000) $fatal(1,"new PC path produced no video");
    $display("PASS UART grant through actual receive/common PHY: continuous clock and no data mute");
    command(2,2);wait(!dut.external_selected);#100000;
    if(dut.pc_play_enabled) $fatal(1,"STOP retained old lease");
    $display("PASS UART STOP returns native on the same physical carrier, no output reset");
    // Make a real read underflow while the input format/clock remain valid.
    // A fault must restart the receiver and return native, not revive START.
    command(1,3);wait(dut.external_selected);
    measuring=0;checking_fault_recovery=1;
    wait(dut.g_common.u_buffer.output_valid &&
         dut.g_common.u_buffer.output_symbols=={10'h133,10'h133,10'h28e});
    @(negedge dut.common_pclk);
    force dut.g_common.u_buffer.fifo_valid=0;
    repeat(3) @(negedge dut.common_pclk);
    release dut.g_common.u_buffer.fifo_valid;
    wait(dut.g_common.buffer_fault);
    wait(!dut.g_common.receiver_epoch);
    #1;
    if(dut.pc_play_enabled) $fatal(1,"FIFO failure did not revoke old UART lease");
    fork
        begin
            wait(dut.input_available && !dut.output_muted);
            if(dut.pc_play_enabled || dut.external_selected || !dut.pc_carrier)
                $fatal(1,"FIFO recovery revived old authorization or changed carrier");
        end
        begin #40000000;$fatal(1,"FIFO recovery did not finish within two full frames plus margin");end
    join_any
    disable fork;
    checking_fault_recovery=0;
    $display("PASS transient FIFO fault recovers with HDMI still valid and old authorization revoked");
    source_on=0;
    wait(!dut.pc_carrier && !dut.output_muted);
    if(dut.pc_play_enabled) $fatal(1,"source loss retained lease");
    $display("PASS actual clock loss returns native with media/network background still running");
    test_pass=1;$finish;
end
initial begin #180000000;$fatal(1,"common ingress timeout ready=%b phase=%b buffer_fault=%b",dut.input_available,dut.g_common.aligned,dut.g_common.buffer_fault);end
initial forever begin
    #1000000;
    $display("TRACE ingress ms=%0.0f carrier=%b ready=%b format=%b phase=%b bfault=%b line_bad=%b good=%0d offsets=%h parser_ready=%b",
        $realtime/1000000.0,dut.pc_carrier,dut.input_available,dut.external_ready,dut.g_common.aligned,
        dut.g_common.buffer_fault,dut.u_relay.u_monitor.line_bad,dut.u_relay.u_monitor.good_count,
        dut.u_relay.u_monitor.bit_offsets,dut.scan_ready);
end
endmodule
