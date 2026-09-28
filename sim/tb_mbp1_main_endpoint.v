`timescale 1ns / 1ps

module tb_mbp1_main_endpoint;
parameter ENABLE_CONTROL = 0;
parameter HOLD_TX_FIELDS = 1;
reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg display_changed = 0;
reg host_send = 0;
reg [7:0] host_type = 8'h01, host_flags = 8'h01;
reg [4:0] host_length = 5'd12;
reg [31:0] host_seq = 32'd1;
reg [127:0] host_payload =
    {8'h02, 8'h02, 8'h01, 8'h01, 32'd0, 32'd0, 32'd0};
wire host_send_ready;
wire host_tx_request, host_tx_valid;
wire [7:0] host_tx_data;
wire [15:0] host_tx_length;
reg host_tx_ack = 0;
wire board_tx_request, board_tx_valid;
wire [7:0] board_tx_data;
wire [15:0] board_tx_length;
reg board_tx_ack = 0;
wire host_rx_valid;
wire [7:0] host_rx_type;
wire [63:0] host_rx_payload;
wire [15:0] board_crc_errors, board_drops, board_retries;
wire peer_alive;
integer ack_count = 0, hello_count = 0, heartbeat_count = 0;
integer display_count = 0, diagnostic_count = 0;
integer command_count = 0;
integer display_before;
reg [7:0] last_ack_result;
wire command_valid;
reg command_done = 0;

mbp1_codec u_host (
    .clk(clk), .rst(rst), .rx_data(board_tx_data),
    .rx_valid(board_tx_valid), .rx_length(board_tx_length),
    .packet_valid(host_rx_valid), .packet_type(host_rx_type),
    .packet_flags(), .packet_payload_length(), .packet_seq(),
    .packet_boot_id(), .packet_uptime_ms(),
    .packet_payload(host_rx_payload), .crc_error_count(), .drop_count(),
    .send(host_send), .send_ready(host_send_ready),
    .send_type(host_type), .send_flags(host_flags),
    .send_payload_length(host_length), .send_seq(host_seq),
    .send_boot_id(32'hb0010001), .send_uptime_ms(32'd0),
    .send_payload(host_payload), .tx_ready(1'b1), .tx_ack(host_tx_ack),
    .tx_request(host_tx_request), .tx_data(host_tx_data),
    .tx_valid(host_tx_valid), .tx_length(host_tx_length)
);

mbp1_main_endpoint #(.CLOCKS_PER_MS(10), .ENABLE_CONTROL(ENABLE_CONTROL),
                     .HOLD_TX_FIELDS(HOLD_TX_FIELDS)) dut (
    .clk(clk), .rst(rst), .rx_data(host_tx_data),
    .rx_valid(host_tx_valid), .rx_length(host_tx_length),
    .tx_ready(1'b1), .tx_ack(board_tx_ack),
    .tx_request(board_tx_request), .tx_data(board_tx_data),
    .tx_valid(board_tx_valid), .tx_length(board_tx_length),
    .local_boot_id(32'ha0010001), .phy_link(1'b1), .main_mode(8'd1),
    .heartbeat_payload(128'd0), .playback_payload(64'd0),
    .display_payload(96'd0), .display_changed(display_changed),
    .diagnostic_payload(128'd0), .command_valid(command_valid), .command_type(),
    .command_seq(), .command_payload(), .command_done(command_done),
    .command_result(8'd0), .peer_alive(peer_alive),
    .crc_error_count(board_crc_errors), .drop_count(board_drops),
    .retry_count(board_retries)
);

always @(negedge clk) begin
    host_tx_ack = host_tx_request;
    board_tx_ack = board_tx_request;
    command_done = command_valid;
end
always @(posedge clk) if (command_done && command_valid)
    command_count <= command_count + 1;
always @(posedge clk) if (dut.send && dut.send_type==8'h01) begin
    if(dut.send_payload[95:64]!==32'h00050003 ||
       dut.send_payload[63:32] !== (ENABLE_CONTROL ? 32'h1ff : 32'h7f))
        $fatal(1,"HELLO version / 1x-pan capability mismatch");
end
always @(posedge clk) if (host_rx_valid) begin
    case (host_rx_type)
        8'h01: hello_count <= hello_count + 1;
        8'h02: heartbeat_count <= heartbeat_count + 1;
        8'h04: begin
            ack_count <= ack_count + 1;
            last_ack_result <= host_rx_payload[23:16];
        end
        8'h16: display_count <= display_count + 1;
        8'h31: diagnostic_count <= diagnostic_count + 1;
        default: $fatal(1, "unexpected board type %02x", host_rx_type);
    endcase
end

task send_packet;
    input [7:0] msg_type;
    input [4:0] length;
    input [127:0] payload;
    begin
        wait (host_send_ready);
        @(negedge clk);
        host_type = msg_type;
        host_length = length;
        host_payload = payload;
        host_send = 1;
        host_seq = host_seq + 32'd1;
        @(negedge clk);
        host_send = 0;
        wait (!host_send_ready);
        wait (host_send_ready);
    end
endtask

initial begin
    repeat (4) @(negedge clk);
    rst = 0;
    wait (hello_count >= 1);
    send_packet(8'h01, 5'd12,
        {8'h02, 8'h02, 8'h01, 8'h01, 32'd0, 32'd0, 32'd0});
    wait (ack_count >= 1);
    if (last_ack_result !== 8'd0) $fatal(1, "HELLO rejected");
    send_packet(8'h03, 5'd0, 128'd0);
    wait (ack_count >= 2 && display_count >= 1 && diagnostic_count >= 1);
    if (last_ack_result !== 8'd0) $fatal(1, "STATUS_QUERY rejected");
    display_before = display_count;
    @(negedge clk); display_changed = 1;
    @(negedge clk); display_changed = 0;
    wait (display_count > display_before);
    // A second update on the exact DISPLAY_STATUS launch cycle must survive
    // clearing the first pending flag, so the newest snapshot is sent too.
    @(negedge clk); display_changed=1;
    @(negedge clk); display_changed=0;
    while (!(dut.select_display && !dut.packet_valid && !command_done &&
             !dut.send && dut.send_ready && dut.tx_gap_ms==0)) @(negedge clk);
    display_changed=1;
    @(posedge clk); #1;
    if(!dut.display_pending) $fatal(1,"display change lost on packet launch");
    @(negedge clk); display_changed=0;
    send_packet(8'h13, 5'd4, {8'd0,8'd1,16'd0,96'd0});
    wait (ack_count >= 3);
    if (last_ack_result !== (ENABLE_CONTROL ? 8'd0 : 8'd3))
        $fatal(1, "control result mismatch");
    if (ENABLE_CONTROL) begin
        host_seq = host_seq - 32'd1;
        send_packet(8'h13, 5'd4, {8'd0,8'd1,16'd0,96'd0});
        wait (ack_count >= 4);
        if (last_ack_result !== 8'd0 || command_count != 1)
            $fatal(1, "duplicate command was replayed");
    end
    send_packet(8'h02, 5'd16, 128'd0);
    repeat (4) @(negedge clk);
    if (!peer_alive) $fatal(1, "heartbeat did not refresh peer state");
    wait (heartbeat_count >= 1);
    send_packet(8'h02, 5'd16, 128'd0);
    repeat (15000) @(negedge clk);
    if (!peer_alive) $fatal(1, "heartbeat expired before two seconds");
    repeat (5010) @(negedge clk);
    if (peer_alive) $fatal(1, "heartbeat failed to expire after two seconds");
    if (board_crc_errors !== 0 || board_drops !== 0)
        $fatal(1, "valid messages rejected");
    $display("PASS: MBP1 HELLO, ACK, STATUS_QUERY, telemetry, dedup and heartbeat; control=%0d", ENABLE_CONTROL);
    $finish;
end
initial begin
    #2000000;
    $fatal(1, "timeout");
end
endmodule
