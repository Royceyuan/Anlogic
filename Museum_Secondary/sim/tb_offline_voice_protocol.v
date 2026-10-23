`timescale 1ns/1ps
module tb_offline_voice_protocol;
reg clk=0,rst=1,main_reset=0,phy_link=1,guide_allowed=1,output_muted=1;
reg [31:0] main_boot=32'ha100,secondary_boot=32'hb100;
reg [127:0] heartbeat=0;
reg [95:0] display=0;
wire m_request,m_valid,s_request,s_valid,main_alive,secondary_alive,main_cap,secondary_cap,lease,muted;
wire [7:0] m_data,s_data;
wire [15:0] m_length,s_length;
reg drop_main=0;
integer mute_confirmations=0,mute_delay=0;
always #5 clk=~clk;
mbp1_main_endpoint #(.CLOCKS_PER_MS(10),.ENABLE_CONTROL(1),.ENABLE_PLAYBACK(1),.ENABLE_GUIDE_AUDIO(1)) main(
    .clk(clk),.rst(rst||main_reset),.rx_data(s_data),.rx_valid(s_valid&&phy_link),.rx_length(s_length),
    .tx_ready(1'b1),.tx_ack(m_request),.tx_request(m_request),.tx_data(m_data),.tx_valid(m_valid),.tx_length(m_length),
    .local_boot_id(main_boot),.phy_link(phy_link),.guide_allowed(guide_allowed),
    .peer_audio_supported(main_cap),.guide_muted_pulse(muted),.main_mode(8'd1),
    .heartbeat_payload(heartbeat),.playback_payload(64'd0),.display_payload(display),.display_changed(1'b0),
    .diagnostic_payload(128'd0),.command_valid(),.command_type(),.command_seq(),.command_payload(),
    .command_done(1'b0),.command_result(8'd0),.peer_alive(main_alive),.crc_error_count(),.drop_count(),.retry_count());
mbp1_secondary_endpoint #(.CLOCKS_PER_MS(10),.ENABLE_GUIDE_AUDIO(1)) secondary(
    .clk(clk),.rst(rst),.phy_link(phy_link),.local_boot_id(secondary_boot),
    .rx_data(m_data),.rx_valid(m_valid&&!drop_main&&phy_link),.rx_length(m_length),
    .tx_ready(1'b1),.tx_ack(s_request),.tx_request(s_request),.tx_data(s_data),.tx_valid(s_valid),.tx_length(s_length),
    .peer_alive(secondary_alive),.peer_session(),.manual_supported(),.output_muted(output_muted),
    .guide_lease_valid(lease),.audio_supported(secondary_cap),.heartbeat_pulse(),.heartbeat_data(),
    .display_pulse(),.display_data(),.diagnostic_pulse(),.diagnostic_data(),
    .control_request(1'b0),.control_type(8'd0),.control_payload(64'd0),
    .control_ready(),.control_done(),.control_result(),.crc_error_count(),.drop_count());
always @(negedge clk)if(muted)mute_confirmations=mute_confirmations+1;
task wait_cycles;
input integer n;
begin repeat(n)@(negedge clk);end endtask
initial begin
    heartbeat[127:120]=1;heartbeat[119:112]=0;heartbeat[111:104]=255;
    display[55:48]=1;display[39:32]=255;
    wait_cycles(5);rst=0;
    wait(lease);wait_cycles(5);
    if(!main_cap||!secondary_cap||!main_alive||!secondary_alive)$fatal(1,"Capabilities/hello not negotiated");
    output_muted=0;guide_allowed=0;
    wait(!lease);wait_cycles(1800);
    if(mute_confirmations!=0)$fatal(1,"Main accepted mute before actual zero-PCM confirmation");
    output_muted=1;wait(mute_confirmations>0);
    guide_allowed=1;wait(lease);output_muted=0;wait_cycles(20);
    // Lost ACKs must expire sound even while cached main status is still alive.
    drop_main=1;wait_cycles(3100);
    if(lease||!secondary_alive)$fatal(1,"300ms lease did not expire independently of 2s heartbeat age");
    drop_main=0;wait(lease);
    phy_link=0;#1;if(lease)$fatal(1,"Physical loss retained sound authorization");
    wait_cycles(5);phy_link=1;wait(lease);
    // New session invalidates the grant before a fresh main can renew it.
    wait(!m_valid&&!s_valid);@(negedge clk);main_boot=32'ha101;main_reset=1;
    wait_cycles(5);main_reset=0;
    wait(secondary.peer_boot_id==main_boot);#1;
    if(lease)$fatal(1,"Old session grant survived main reboot");
    wait(lease);guide_allowed=0;output_muted=0;
    wait(!lease);wait_cycles(1200);output_muted=1;
    wait(muted);
    $display("PASS voice lease over real MBP1 byte streams: capabilities, actual mute echo, renewal, 300ms expiry, cable loss, new boot");$finish;
end
initial begin #2000000;$fatal(1,"Voice protocol timeout cap %b/%b alive %b/%b lease %b",main_cap,secondary_cap,main_alive,secondary_alive,lease);end
endmodule
