`timescale 1ns / 1ps
`default_nettype none

module museum_lecture_controller #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer ART0_PHASE_SECONDS = 15,
    parameter integer ART1_PHASE_SECONDS = 8,
    parameter integer ART2_PHASE_SECONDS = 14,
    parameter integer ART3_PHASE_SECONDS = 14,
    parameter integer ART4_PHASE_SECONDS = 16
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       confirm_pulse,
    input  wire [2:0] selected_index,
    output reg        load_request,
    input  wire       load_accept,
    input  wire       load_complete,
    input  wire       load_error,
    output reg  [1:0] load_slot,
    output wire       load_detail,
    output wire [1:0] detail_index,
    output reg  [2:0] artifact_index,
    output reg        preloading,
    output reg        lecture_active,
    output reg        lecture_finished,
    output reg  [1:0] display_slot,
    output reg        media_error
);

reg waiting_for_load;
reg [31:0] phase_count;

wire [31:0] phase_cycles =
    (artifact_index == 3'd0) ? CLOCK_HZ * ART0_PHASE_SECONDS :
    (artifact_index == 3'd1) ? CLOCK_HZ * ART1_PHASE_SECONDS :
    (artifact_index == 3'd2) ? CLOCK_HZ * ART2_PHASE_SECONDS :
    (artifact_index == 3'd3) ? CLOCK_HZ * ART3_PHASE_SECONDS :
                               CLOCK_HZ * ART4_PHASE_SECONDS;

assign load_detail = (load_slot != 2'd0);
assign detail_index = load_slot;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        load_request    <= 1'b0;
        waiting_for_load<= 1'b0;
        load_slot       <= 2'd0;
        artifact_index  <= 3'd0;
        preloading      <= 1'b0;
        lecture_active  <= 1'b0;
        lecture_finished<= 1'b0;
        display_slot    <= 2'd0;
        media_error     <= 1'b0;
        phase_count     <= 32'd0;
    end else begin
        if (enable && confirm_pulse && !preloading && !lecture_active) begin
            artifact_index   <= selected_index;
            load_slot        <= 2'd0;
            load_request     <= 1'b1;
            waiting_for_load <= 1'b0;
            preloading       <= 1'b1;
            lecture_finished <= 1'b0;
            display_slot     <= 2'd0;
            media_error      <= 1'b0;
            phase_count      <= 32'd0;
        end

        if (preloading && load_request && load_accept) begin
            load_request     <= 1'b0;
            waiting_for_load <= 1'b1;
        end

        if (preloading && waiting_for_load && load_error) begin
            waiting_for_load <= 1'b0;
            preloading       <= 1'b0;
            media_error      <= 1'b1;
        end else if (preloading && waiting_for_load && load_complete) begin
            waiting_for_load <= 1'b0;
            if (load_slot == 2'd3) begin
                preloading      <= 1'b0;
                lecture_active  <= 1'b1;
                lecture_finished<= 1'b0;
                display_slot    <= 2'd0;
                phase_count     <= 32'd0;
            end else begin
                load_slot    <= load_slot + 1'b1;
                load_request <= 1'b1;
            end
        end

        if (lecture_active && !lecture_finished) begin
            if (phase_count == phase_cycles - 1'b1) begin
                phase_count <= 32'd0;
                if (display_slot == 2'd3)
                    lecture_finished <= 1'b1;
                else
                    display_slot <= display_slot + 1'b1;
            end else begin
                phase_count <= phase_count + 1'b1;
            end
        end
    end
end

endmodule

`default_nettype wire
