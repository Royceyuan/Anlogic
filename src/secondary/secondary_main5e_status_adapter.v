`timescale 1ns / 1ps
`default_nettype none

// Translate the main board's current-state heartbeat to the existing local
// display controller. Preload target (byte 14 low nibble) and confirmed
// lecture (byte 2 = 0..4) are intentionally separate.
module secondary_main5e_status_adapter (
    input wire clk,
    input wire rst,
    input wire heartbeat_pulse,
    input wire [127:0] heartbeat_data,
    output reg cmd_valid,
    output reg [7:0] cmd_type,
    output reg [7:0] cmd_artifact_id,
    output reg [7:0] cmd_mode,
    output reg [7:0] cmd_lecture_phase,
    output reg cmd_emergency_active
);
reg heartbeat_queued;
reg [127:0] queued_data;
reg [3:0] last_preload_target;
wire [3:0] preload_target = heartbeat_data[71] ? heartbeat_data[11:8] : 4'hf;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cmd_valid <= 0; cmd_type <= 0; cmd_artifact_id <= 8'hff;
        cmd_mode <= 0; cmd_lecture_phase <= 8'hff;
        cmd_emergency_active <= 0;
        heartbeat_queued <= 0; queued_data <= 0;
        last_preload_target <= 4'hf;
    end else begin
        cmd_valid <= 0;
        if (heartbeat_queued) begin
            cmd_valid <= 1;
            cmd_type <= 8'h02;
            cmd_artifact_id <= queued_data[119:112];
            cmd_lecture_phase <= queued_data[111:104];
            cmd_mode <= queued_data[111:104] == 8'hff ? 8'd1 :
                        queued_data[111:104] <= 8'd4 ? 8'd2 : 8'd0;
            cmd_emergency_active <= queued_data[95:88] != 8'd0;
            heartbeat_queued <= 0;
        end else if (heartbeat_pulse) begin
            queued_data <= heartbeat_data;
            if (preload_target <= 4'd4 &&
                preload_target != last_preload_target) begin
                cmd_valid <= 1;
                cmd_type <= 8'h10;
                cmd_artifact_id <= {4'd0, preload_target};
                cmd_mode <= 0;
                last_preload_target <= preload_target;
            end else if (preload_target > 4'd4)
                last_preload_target <= 4'hf;
            heartbeat_queued <= 1;
        end
    end
end
endmodule

`default_nettype wire
