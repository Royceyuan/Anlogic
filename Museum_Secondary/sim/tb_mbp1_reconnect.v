`timescale 1ns/1ps
// Both production endpoints, including secondary switch reconciliation.
module tb_mbp1_reconnect;
reg clk=0, rst=1, main_rst=1, link=1, cable=1, allow_display=1;
always #5 clk=~clk;
reg manual=0, done=0;
reg [7:0] result=0;
reg [31:0] main_boot=32'h12345678;
wire m_req,m_valid,s_req,s_valid,command_valid,request,ready,alive,supported;
wire [7:0] m_data,s_data,command_type,request_type;
wire [15:0] m_length,s_length;
wire [63:0] command_payload,request_payload;
wire hb_pulse,display_pulse;
wire [127:0] hb_data;
wire [95:0] display_data;
reg test_pass=0;
integer commands=0,hello_packets=0;
reg [127:0] hb;
reg [95:0] display;
always @* begin
    hb=128'h0100ff00000000800000000000002000;
    display=96'h00030203030102ff00000000;
    display[42]=manual;
end
mbp1_main_endpoint #(.CLOCKS_PER_MS(100),.ENABLE_CONTROL(1),.HOLD_TX_FIELDS(0)) main (
    .clk(clk),.rst(main_rst),.phy_link(link),.local_boot_id(main_boot),.main_mode(8'd1),
    .rx_data(s_data),.rx_valid(s_valid&&cable),.rx_length(s_length),
    .tx_ready(1'b1),.tx_ack(m_req),.tx_request(m_req),.tx_data(m_data),
    .tx_valid(m_valid),.tx_length(m_length),.heartbeat_payload(hb),
    .playback_payload(64'd0),.display_payload(display),.display_changed(done),
    .diagnostic_payload(128'd0),.command_valid(command_valid),.command_type(command_type),
    .command_seq(),.command_payload(command_payload),.command_done(done),
    .command_result(result),.peer_alive(),.crc_error_count(),.drop_count(),.retry_count());
mbp1_secondary_endpoint #(.CLOCKS_PER_MS(100)) secondary (
    .clk(clk),.rst(rst),.phy_link(link),.local_boot_id(32'h87654321),
    .rx_data(m_data),.rx_valid(m_valid&&cable&&(allow_display||main.send_type!=8'h16)),.rx_length(m_length),
    .tx_ready(1'b1),.tx_ack(s_req),.tx_request(s_req),.tx_data(s_data),
    .tx_valid(s_valid),.tx_length(s_length),.peer_alive(alive),.manual_supported(supported),
    .heartbeat_pulse(hb_pulse),.heartbeat_data(hb_data),
    .display_pulse(display_pulse),.display_data(display_data),
    .diagnostic_pulse(),.diagnostic_data(),.control_request(request),
    .control_type(request_type),.control_payload(request_payload),
    .control_ready(ready),.control_done(),.control_result(),.crc_error_count(),.drop_count());
secondary_main5e_keys keys (
    .clk(clk),.rst(rst),.sw(4'd0),.key_n(4'hf),
    .heartbeat_pulse(hb_pulse),.heartbeat_data(hb_data),
    .display_pulse(display_pulse),.display_data(display_data),
    .control_ready(ready),.peer_alive(alive),.manual_supported(supported),
    .control_request(request),.control_type(request_type),.control_payload(request_payload),
    .manual_mode(),.manual_next(),.help_switches());
always @(posedge clk) begin
    done<=0;
    if(main_rst) manual<=0;
    else if(command_valid&&!done) begin
        done<=1; result<=0; commands=commands+1;
        if(command_type==8'h17) manual<=command_payload[56];
    end
    if(main.send&&main.send_type==8'h01) hello_packets=hello_packets+1;
end
task settle;
    input expected_mode;
    integer timeout;
    begin
        timeout=0;
        while(!(alive&&supported&&ready&&manual==expected_mode&&
                display_data[42]==expected_mode)&&timeout<400000) begin
            @(negedge clk);timeout=timeout+1;
        end
        if(timeout==400000)
            $fatal(1,"reconnect failed: mode=%b expected=%b alive=%b cap=%b ready=%b hello=%d",
                   manual,expected_mode,alive,supported,ready,hello_packets);
        repeat(500) @(negedge clk);
    end
endtask
task disconnect;
    input integer ticks;
    input target;
    begin
        @(negedge clk);cable=0;link=0;
        force keys.sw_stable={1'b0,target,2'b00};
        repeat(ticks) @(negedge clk);
        if(alive||supported) $fatal(1,"offline controls must be blocked");
        cable=1;link=1;
        settle(target);
    end
endtask
integer loop_index,hello_before,commands_before;
initial begin
    force keys.sw_stable=4'b0000;
    repeat(5) @(negedge clk);rst=0;main_rst=0;
    settle(0);
    force keys.sw_stable=4'b0100;
    settle(1);
    // Real main and secondary codecs exchange HELLO/ACK/telemetry: no injected
    // capability packet and neither boot ID changes when the cable returns.
    disconnect(5000,0);
    disconnect(250000,1);
    for(loop_index=0;loop_index<4;loop_index=loop_index+1)
        disconnect(300,loop_index[0]);
    // Same mode held across disconnection must also regain controls.
    disconnect(5000,1);
    // Cached capability is not cached applied state: HB alone must not unlock.
    cable=0;link=0;allow_display=0;
    force keys.sw_stable=4'b0000;
    repeat(5000) @(negedge clk);
    cable=1;link=1;
    repeat(100000) @(negedge clk);
    if(ready||request||manual!=1) $fatal(1,"stale display unlocked control");
    allow_display=1;
    settle(0);
    // A cable pulled while awaiting an ACK must not replay the old request.
    force keys.sw_stable=4'b0100;
    wait(secondary.control_waiting&&secondary.control_sent);
    disconnect(5000,0);
    // The original preset keys also work after recovery, not only SW3.
    commands_before=commands;
    force keys.key_press=4'b0001;
    repeat(2) @(negedge clk);
    release keys.key_press;
    repeat(100000) @(negedge clk);
    if(commands!=commands_before+1||!ready) $fatal(1,"preset key did not recover");
    hello_before=hello_packets;
    repeat(120000) @(negedge clk);
    if(hello_packets!=hello_before) $fatal(1,"HELLO ping-pong after recovery");
    force keys.sw_stable=4'b0000;
    settle(0);
    // Packet silence also needs re-handshake even if MDIO misses link loss.
    cable=0;
    repeat(600000) @(negedge clk);
    force keys.sw_stable=4'b0100;
    cable=1;
    settle(1);
    // A genuine main reboot still refreshes capability and applied mode.
    @(negedge clk);main_boot=32'habcdef01;main_rst=1;
    repeat(5) @(negedge clk);main_rst=0;
    repeat(1000) @(negedge clk);
    settle(1);
    if(commands<9) $fatal(1,"mode commands missing");
    $display("PASS same-boot reconnect, switch reconciliation, timeout, no HELLO loop: commands=%0d",commands);
    test_pass=1;$finish;
end
initial begin #30000000;$fatal(1,"test timeout");end
endmodule
