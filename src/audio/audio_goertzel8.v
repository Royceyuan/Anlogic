`default_nettype none

// Eight fixed 256-point DFT bins.  A single signed multiplier is selected
// by the small sequencer, so spectrum presentation costs one DSP rather than
// a parallel FFT engine.  Coefficients are Q2.14 for recurrence and Q1.15
// for the terminal real/imaginary estimate.
module audio_goertzel8 (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_valid,
    input  wire signed [15:0] sample_left,
    input  wire signed [15:0] sample_right,
    input  wire               frame_tick,
    output reg [7:0]          bar0,
    output reg [7:0]          bar1,
    output reg [7:0]          bar2,
    output reg [7:0]          bar3,
    output reg [7:0]          bar4,
    output reg [7:0]          bar5,
    output reg [7:0]          bar6,
    output reg [7:0]          bar7
);

localparam [2:0] ST_IDLE = 3'd0, ST_REC = 3'd1,
                 ST_MAG_COS = 3'd2, ST_MAG_SIN = 3'd3,
                 ST_TERM = 3'd4;

reg [2:0] state;
reg [2:0] bin;
reg [7:0] sample_count;
reg signed [15:0] sample_q;
reg signed [15:0] s1 [0:7];
reg signed [15:0] s2 [0:7];
reg signed [15:0] cos_q;
reg signed [15:0] sin_q;
reg [7:0] raw [0:7];
reg [7:0] next_raw [0:7];
integer i;

function signed [15:0] coeff_q214;
    input [2:0] index;
    begin
        case (index)
            3'd0: coeff_q214 = 16'sd32758; // 187.5 Hz
            3'd1: coeff_q214 = 16'sd32729; // 375 Hz
            3'd2: coeff_q214 = 16'sd32610; // 750 Hz
            3'd3: coeff_q214 = 16'sd32138; // 1.5 kHz
            3'd4: coeff_q214 = 16'sd30274; // 3 kHz
            3'd5: coeff_q214 = 16'sd23170; // 6 kHz
            3'd6: coeff_q214 = 16'sd0;     // 12 kHz
            default: coeff_q214 = -16'sd23170; // 18 kHz
        endcase
    end
endfunction

function signed [15:0] sin_q115;
    input [2:0] index;
    begin
        case (index)
            3'd0: sin_q115 = 16'sd804;
            3'd1: sin_q115 = 16'sd1608;
            3'd2: sin_q115 = 16'sd3212;
            3'd3: sin_q115 = 16'sd6393;
            3'd4: sin_q115 = 16'sd12540;
            3'd5: sin_q115 = 16'sd23170;
            3'd6: sin_q115 = 16'sd32767;
            default: sin_q115 = 16'sd23170;
        endcase
    end
endfunction

function signed [15:0] sat16;
    input signed [33:0] value;
    begin
        if (value > 34'sd32767)
            sat16 = 16'sd32767;
        else if (value < -34'sd32768)
            sat16 = -16'sd32768;
        else
            sat16 = value[15:0];
    end
endfunction

function [7:0] magnitude_to_height;
    input [17:0] magnitude;
    integer height;
    begin
        // A logarithmic display keeps quiet and loud WAV material readable.
        if (magnitude < 18'd64)
            height = 0;
        else if (magnitude[17]) height = 136;
        else if (magnitude[16]) height = 128;
        else if (magnitude[15]) height = 112;
        else if (magnitude[14]) height = 96;
        else if (magnitude[13]) height = 80;
        else if (magnitude[12]) height = 64;
        else if (magnitude[11]) height = 48;
        else if (magnitude[10]) height = 32;
        else if (magnitude[9])  height = 20;
        else if (magnitude[8])  height = 12;
        else                     height = 6;
        magnitude_to_height = height[7:0];
    end
endfunction

function [16:0] abs17;
    input signed [16:0] value;
    begin
        abs17 = value[16] ? -value : value;
    end
endfunction

reg signed [15:0] mul_a;
reg signed [15:0] mul_b;
// Make the product width explicit.  Verilog otherwise evaluates this mixed
// width multiply at the operand width in some synthesis/simulation flows.
wire signed [31:0] mul_p = {{16{mul_a[15]}},mul_a} * {{16{mul_b[15]}},mul_b};
wire signed [33:0] sample_ext = {{18{sample_q[15]}},sample_q};
wire signed [33:0] product_ext = {{2{mul_p[31]}},mul_p};
wire signed [33:0] s2_ext = {{18{s2[bin][15]}},s2[bin]};
wire signed [33:0] recurrence_value =
    sample_ext + (product_ext >>> 14) - s2_ext;
wire signed [16:0] terminal_real = {s1[bin][15],s1[bin]} - {cos_q[15],cos_q};
wire signed [16:0] terminal_imag = {sin_q[15],sin_q};
wire [17:0] terminal_magnitude = abs17(terminal_real) + abs17(terminal_imag);
wire signed [15:0] mono_left  = {{9{sample_left[15]}}, sample_left[15:9]};
wire signed [15:0] mono_right = {{9{sample_right[15]}}, sample_right[15:9]};
wire signed [15:0] mono_small = (mono_left + mono_right) >>> 1;

always @(*) begin
    mul_a = 16'sd0;
    mul_b = 16'sd0;
    case (state)
        ST_REC: begin
            mul_a = s1[bin];
            mul_b = coeff_q214(bin);
        end
        ST_MAG_COS: begin
            mul_a = s2[bin];
            mul_b = coeff_q214(bin);
        end
        ST_MAG_SIN: begin
            mul_a = s2[bin];
            mul_b = sin_q115(bin);
        end
        default: begin end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state        <= ST_IDLE;
        bin          <= 3'd0;
        sample_count <= 8'd0;
        sample_q     <= 16'sd0;
        cos_q        <= 16'sd0;
        sin_q        <= 16'sd0;
        bar0 <= 0; bar1 <= 0; bar2 <= 0; bar3 <= 0;
        bar4 <= 0; bar5 <= 0; bar6 <= 0; bar7 <= 0;
        for (i=0; i<8; i=i+1) begin
            s1[i] <= 16'sd0;
            s2[i] <= 16'sd0;
            raw[i] <= 8'd0;
            next_raw[i] <= 8'd0;
        end
    end else begin
        // Present the latest complete analysis at the video frame boundary.
        // This removes stale peak hold and keeps the HDMI-domain display stable.
        if (frame_tick) begin
            bar0 <= raw[0]; bar1 <= raw[1]; bar2 <= raw[2]; bar3 <= raw[3];
            bar4 <= raw[4]; bar5 <= raw[5]; bar6 <= raw[6]; bar7 <= raw[7];
        end

        case (state)
            ST_IDLE: if (sample_valid) begin
                sample_q <= mono_small;
                bin <= 3'd0;
                state <= ST_REC;
            end
            ST_REC: begin
                // The first sample of each 256-point block replaces stale
                // resonator state; later samples use the normal recurrence.
                if (sample_count == 8'd0) begin
                    s2[bin] <= 16'sd0;
                    s1[bin] <= sample_q;
                end else begin
                    s2[bin] <= s1[bin];
                    s1[bin] <= sat16(recurrence_value);
                end
                if (bin == 3'd7) begin
                    if (sample_count == 8'd255) begin
                        sample_count <= 8'd0;
                        bin <= 3'd0;
                        state <= ST_MAG_COS;
                    end else begin
                        sample_count <= sample_count + 1'b1;
                        state <= ST_IDLE;
                    end
                end else begin
                    bin <= bin + 1'b1;
                end
            end
            ST_MAG_COS: begin
                cos_q <= mul_p >>> 15;
                state <= ST_MAG_SIN;
            end
            ST_MAG_SIN: begin
                sin_q <= mul_p >>> 15;
                state <= ST_TERM;
            end
            ST_TERM: begin
                // Terminal magnitude stage is multiplier-free; sin_q and
                // cos_q were registered by the preceding two cycles.
                next_raw[bin] <= magnitude_to_height(terminal_magnitude);
                if (bin == 3'd7) begin
                    raw[0] <= next_raw[0]; raw[1] <= next_raw[1];
                    raw[2] <= next_raw[2]; raw[3] <= next_raw[3];
                    raw[4] <= next_raw[4]; raw[5] <= next_raw[5];
                    raw[6] <= next_raw[6]; raw[7] <= magnitude_to_height(terminal_magnitude);
                    bin <= 3'd0;
                    state <= ST_IDLE;
                end else begin
                    bin <= bin + 1'b1;
                    state <= ST_MAG_COS;
                end
            end
            default: state <= ST_IDLE;
        endcase
    end
end

endmodule

`default_nettype wire
