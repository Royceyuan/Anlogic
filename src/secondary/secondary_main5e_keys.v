`timescale 1ns / 1ps
`default_nettype none

// One debounced press produces one absolute request from the latest applied
// main-board status. An in-flight request is owned by the MBP1 endpoint.
module secondary_main5e_keys (
    input wire clk,
    input wire rst,
    input wire [3:0] sw,
    input wire [3:0] key_n,
    input wire heartbeat_pulse,
    input wire [127:0] heartbeat_data,
    input wire display_pulse,
    input wire [95:0] display_data,
    input wire control_ready,
    input wire peer_alive,
    input wire manual_supported,
    output reg control_request,
    output reg [7:0] control_type,
    output reg [63:0] control_payload,
    output wire manual_mode,
    output wire manual_next,
    output wire [3:0] help_switches
);
wire [3:0] key_press;
key_debounce u_keys (
    .clk(clk), .rst_n(!rst), .key_n(key_n),
    .key_level_n(), .key_press_pulse(key_press),
    .key_release_pulse()
);
reg [3:0] sw_ff1, sw_ff2, sw_stable;
reg [19:0] sw_settle;
assign help_switches = sw_stable;
assign manual_mode = 1'b0;
reg [127:0] hb;
reg [95:0] display;
reg hb_seen, display_seen;
reg desired_manual_d, mode_retry_ready;
wire [7:0] hb_artifact = hb[119:112];
wire [7:0] hb_phase = hb[111:104];
// SW4 changes only the local help page. All four remote keys remain active.
assign manual_next = 1'b0;
wire hb_emergency = hb[95:88] != 0;
wire hb_restoring = hb[70];
wire [1:0] mode = sw_stable[1:0];
wire [7:0] step = 8'd1;
wire signed [16:0] pan_step = 17'sd20;
wire mode_matches = display[42] == sw_stable[2];
wire main_safe = !hb_emergency && !hb_restoring &&
                 (hb[127:120] == 1 || hb[127:120] == 2) &&
                 (hb[103:96] == 0 || hb[103:96] == 1 ||
                  hb[103:96] == 2 || hb[103:96] == 5);
wire [7:0] key_code = key_press[0] ? 8'd0 :
                      key_press[1] ? 8'd1 :
                      key_press[2] ? 8'd2 : 8'd3;

function [7:0] bounded_step;
    input [7:0] old_value, maximum, amount;
    input increase;
    reg [8:0] sum;
    begin
        sum = {1'b0, old_value} + {1'b0, amount};
        if (increase) bounded_step = sum > maximum ? maximum : sum[7:0];
        else bounded_step = old_value < amount ? 8'd0 : old_value - amount;
    end
endfunction
function [15:0] bounded_pan;
    input [15:0] old_value;
    input signed [16:0] amount;
    input signed [16:0] limit;
    reg signed [16:0] next_value;
    begin
        next_value = $signed({old_value[15],old_value}) + amount;
        if (next_value > limit) next_value = limit;
        if (next_value < -limit) next_value = -limit;
        bounded_pan = next_value[15:0];
    end
endfunction

reg [7:0] brightness, contrast, saturation, temperature;
reg [15:0] pan_x, pan_y;
always @* begin
    brightness = display[87:80];
    contrast = display[79:72];
    saturation = display[71:64];
    temperature = display[63:56];
    pan_x = display[31:16];
    pan_y = display[15:0];
    case (mode)
        2'b01: case (key_code)
            0: brightness = bounded_step(brightness, 8'd6, step, 1'b0);
            1: brightness = bounded_step(brightness, 8'd6, step, 1'b1);
            2: contrast = bounded_step(contrast, 8'd4, step, 1'b0);
            3: contrast = bounded_step(contrast, 8'd4, step, 1'b1);
        endcase
        2'b10: case (key_code)
            0: saturation = bounded_step(saturation, 8'd5, step, 1'b0);
            1: saturation = bounded_step(saturation, 8'd5, step, 1'b1);
            2: temperature = bounded_step(temperature, 8'd6, step, 1'b0);
            3: temperature = bounded_step(temperature, 8'd6, step, 1'b1);
        endcase
        2'b11: case (key_code)
            0: pan_x = bounded_pan(pan_x, -pan_step, 17'sd240);
            1: pan_x = bounded_pan(pan_x,  pan_step, 17'sd240);
            2: pan_y = bounded_pan(pan_y, -pan_step, 17'sd135);
            3: pan_y = bounded_pan(pan_y,  pan_step, 17'sd135);
        endcase
        default: begin end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sw_ff1 <= 0; sw_ff2 <= 0; sw_stable <= 0; sw_settle <= 0;
        hb <= 0; display <= 0; hb_seen <= 0; display_seen <= 0;
        desired_manual_d <= 0; mode_retry_ready <= 1;
        control_request <= 0; control_type <= 0; control_payload <= 0;
    end else begin
        sw_ff1 <= sw; sw_ff2 <= sw_ff1;
        if (sw_ff2 != sw_stable) begin
            if (sw_settle == 20'd999999) begin
                sw_stable <= sw_ff2;
                sw_settle <= 0;
            end else sw_settle <= sw_settle + 20'd1;
        end else sw_settle <= 0;
        if (heartbeat_pulse) begin hb <= heartbeat_data; hb_seen <= 1; end
        if (display_pulse) begin display <= display_data; display_seen <= 1; end
        desired_manual_d <= sw_stable[2];
        if (!peer_alive) begin
            hb_seen <= 0; display_seen <= 0;
            mode_retry_ready <= 1;
        end else if (desired_manual_d != sw_stable[2] || mode_matches ||
                     hb_restoring || hb_emergency) begin
            mode_retry_ready <= 1;
        end else if (heartbeat_pulse && control_ready) mode_retry_ready <= 1;
        control_request <= 0;
        if (!control_request && control_ready && peer_alive && hb_seen &&
            display_seen && main_safe) begin
            // Reconcile the switch with applied state after recovery/reconnection.
            // BUSY gets a new sequence only after a fresh heartbeat. Loading
            // can outlast ten heartbeats; reconcile until applied state matches.
            // Individual packet retries remain bounded by the endpoint.
            if (manual_supported && !mode_matches && mode_retry_ready) begin
                control_type <= 8'h17;
                control_payload <= {7'd0,sw_stable[2],56'd0};
                control_request <= 1;
                mode_retry_ready <= 0;
            end else if ((|key_press) && mode_matches) begin
            if (mode == 2'b00) begin
                control_type <= 8'h13;
                control_payload <= {6'd0,key_code[1:0],8'd1,16'd0,32'd0};
                control_request <= 1;
            end else if (mode == 2'b01 || mode == 2'b10) begin
                control_type <= 8'h14;
                control_payload <= {brightness,contrast,saturation,temperature,
                                    8'd1,8'd0,16'd0};
                control_request <= 1;
            end else if (hb_artifact <= 8'd4 && hb_phase <= 8'd4 &&
                         hb[71] && display[39:32] == hb_phase &&
                         (display[55:48] == 8'd1 || display[55:48] == 8'd2)) begin
                control_type <= 8'h15;
                control_payload <= {hb_artifact,hb_phase,display[55:48],8'd0,
                                    pan_x,pan_y};
                control_request <= 1;
            end
            end
        end
    end
end
endmodule

`default_nettype wire
