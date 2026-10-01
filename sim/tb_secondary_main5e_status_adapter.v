`timescale 1ns/1ps
module tb_secondary_main5e_status_adapter;
reg clk=0, rst=1, hb_pulse=0;
always #5 clk=~clk;
reg [127:0] hb=0;
wire cmd_valid, emergency;
wire [7:0] cmd_type, cmd_artifact, cmd_mode, cmd_phase;
wire cmd_emergency;
wire [2:0] page, resume_page, master, preload, info_artifact, result;
wire [1:0] link_state;
wire info_active;
wire [7:0] route;
secondary_main5e_status_adapter adapter (
    .clk(clk), .rst(rst), .heartbeat_pulse(hb_pulse),
    .heartbeat_data(hb), .cmd_valid(cmd_valid),
    .cmd_type(cmd_type), .cmd_artifact_id(cmd_artifact),
    .cmd_mode(cmd_mode), .cmd_lecture_phase(cmd_phase),
    .cmd_emergency_active(cmd_emergency)
);
secondary_carousel_controller #(.PAGE_CYCLES(10),
    .LINK_TIMEOUT_CYCLES(100), .STREAMING(1)) controller (
    .clk(clk), .rst_n(!rst), .frame_valid(5'b11111),
    .page_ready(1'b1), .displayed_artifact(3'd2),
    .local_emergency(1'b0), .manual_mode(1'b0),
    .manual_next(1'b0), .cmd_valid(cmd_valid),
    .cmd_type(cmd_type), .cmd_artifact_id(cmd_artifact),
    .cmd_confirmed(1'b0), .cmd_mode(cmd_mode),
    .cmd_lecture_phase(cmd_phase), .cmd_lecture_reason(8'd0),
    .cmd_emergency_id(16'd0), .cmd_route_id(8'd0),
    .cmd_emergency_active(cmd_emergency),
    .page_index(page), .resume_page_index(resume_page),
    .emergency_active(emergency), .link_state(link_state),
    .master_artifact(master), .preload_artifact(preload),
    .info_active(info_active), .info_artifact(info_artifact),
    .active_route_id(route), .cmd_result(result)
);
task state;
    input [7:0] artifact, phase, urgent;
    input [3:0] target;
    begin
        @(negedge clk);
        hb={8'd1, artifact, phase, 8'd1, urgent, 8'd0,
            8'd0, 8'h80, 32'd0, 16'd0, 4'h0, target,
            8'hff};
        hb_pulse=1;
        @(negedge clk); hb_pulse=0;
        repeat(5) @(negedge clk);
    end
endtask
initial begin
    repeat(3) @(negedge clk); rst=0;
    state(8'd2,8'hff,8'd0,4'd3);
    if (info_active || preload!=3 || master!=2 || link_state!=1)
        $fatal(1,"overview must preload without switching");
    repeat(4) state(8'd2,8'hff,8'd0,4'd3);
    if (page==0)
        $fatal(1,"periodic overview heartbeat stopped the carousel");
    state(8'd2,8'd0,8'd0,4'd3);
    if (!info_active || info_artifact!=2)
        $fatal(1,"confirmed lecture must show actual artifact");
    state(8'd2,8'd0,8'd1,4'd4);
    if (!emergency || preload!=4)
        $fatal(1,"emergency must override lecture");
    state(8'd2,8'd0,8'd0,4'd4);
    if (emergency) $fatal(1,"fresh heartbeat must clear emergency");
    state(8'd1,8'hff,8'd0,4'd4);
    if (info_active || preload!=4)
        $fatal(1,"overview must resume carousel");
    $display("PASS tb_secondary_main5e_status_adapter");
    $finish;
end
initial begin #20000; $fatal(1,"timeout"); end
endmodule
