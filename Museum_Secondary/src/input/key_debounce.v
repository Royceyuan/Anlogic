`timescale 1ns / 1ps
`default_nettype none

module key_debounce #(
    parameter integer DEBOUNCE_BITS = 19
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] key_n,
    output reg  [3:0] key_level_n,
    output reg  [3:0] key_press_pulse,
    output reg  [3:0] key_release_pulse
);

reg key_sync0_0, key_sync1_0, key_stable_0;
reg key_sync0_1, key_sync1_1, key_stable_1;
reg key_sync0_2, key_sync1_2, key_stable_2;
reg key_sync0_3, key_sync1_3, key_stable_3;

reg [DEBOUNCE_BITS-1:0] cnt_0;
reg [DEBOUNCE_BITS-1:0] cnt_1;
reg [DEBOUNCE_BITS-1:0] cnt_2;
reg [DEBOUNCE_BITS-1:0] cnt_3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_sync0_0 <= 1'b1;
        key_sync1_0 <= 1'b1;
        key_stable_0 <= 1'b1;
        cnt_0 <= {DEBOUNCE_BITS{1'b0}};

        key_sync0_1 <= 1'b1;
        key_sync1_1 <= 1'b1;
        key_stable_1 <= 1'b1;
        cnt_1 <= {DEBOUNCE_BITS{1'b0}};

        key_sync0_2 <= 1'b1;
        key_sync1_2 <= 1'b1;
        key_stable_2 <= 1'b1;
        cnt_2 <= {DEBOUNCE_BITS{1'b0}};

        key_sync0_3 <= 1'b1;
        key_sync1_3 <= 1'b1;
        key_stable_3 <= 1'b1;
        cnt_3 <= {DEBOUNCE_BITS{1'b0}};

        key_level_n <= 4'b1111;
        key_press_pulse <= 4'b0000;
        key_release_pulse <= 4'b0000;
    end else begin
        key_press_pulse <= 4'b0000;
        key_release_pulse <= 4'b0000;

        key_sync0_0 <= key_n[0];
        key_sync1_0 <= key_sync0_0;
        if (key_sync1_0 != key_stable_0) begin
            cnt_0 <= cnt_0 + {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
            if (&cnt_0) begin
                key_press_pulse[0] <= key_stable_0 & ~key_sync1_0;
                key_release_pulse[0] <= ~key_stable_0 & key_sync1_0;
                key_stable_0 <= key_sync1_0;
                cnt_0 <= {DEBOUNCE_BITS{1'b0}};
            end
        end else begin
            cnt_0 <= {DEBOUNCE_BITS{1'b0}};
        end

        key_sync0_1 <= key_n[1];
        key_sync1_1 <= key_sync0_1;
        if (key_sync1_1 != key_stable_1) begin
            cnt_1 <= cnt_1 + {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
            if (&cnt_1) begin
                key_press_pulse[1] <= key_stable_1 & ~key_sync1_1;
                key_release_pulse[1] <= ~key_stable_1 & key_sync1_1;
                key_stable_1 <= key_sync1_1;
                cnt_1 <= {DEBOUNCE_BITS{1'b0}};
            end
        end else begin
            cnt_1 <= {DEBOUNCE_BITS{1'b0}};
        end

        key_sync0_2 <= key_n[2];
        key_sync1_2 <= key_sync0_2;
        if (key_sync1_2 != key_stable_2) begin
            cnt_2 <= cnt_2 + {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
            if (&cnt_2) begin
                key_press_pulse[2] <= key_stable_2 & ~key_sync1_2;
                key_release_pulse[2] <= ~key_stable_2 & key_sync1_2;
                key_stable_2 <= key_sync1_2;
                cnt_2 <= {DEBOUNCE_BITS{1'b0}};
            end
        end else begin
            cnt_2 <= {DEBOUNCE_BITS{1'b0}};
        end

        key_sync0_3 <= key_n[3];
        key_sync1_3 <= key_sync0_3;
        if (key_sync1_3 != key_stable_3) begin
            cnt_3 <= cnt_3 + {{(DEBOUNCE_BITS-1){1'b0}}, 1'b1};
            if (&cnt_3) begin
                key_press_pulse[3] <= key_stable_3 & ~key_sync1_3;
                key_release_pulse[3] <= ~key_stable_3 & key_sync1_3;
                key_stable_3 <= key_sync1_3;
                cnt_3 <= {DEBOUNCE_BITS{1'b0}};
            end
        end else begin
            cnt_3 <= {DEBOUNCE_BITS{1'b0}};
        end

        key_level_n <= {key_stable_3, key_stable_2, key_stable_1, key_stable_0};
    end
end

endmodule

`default_nettype wire
