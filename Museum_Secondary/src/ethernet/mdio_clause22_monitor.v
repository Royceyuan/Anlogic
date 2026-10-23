`timescale 1ns / 1ps
`default_nettype none

module mdio_clause22_monitor #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer MDC_HZ = 1_250_000,
    parameter integer POLL_GAP_CYCLES = 50_000,
    parameter [4:0] PHY_ADDR = 5'd1
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        mdio_i,
    output reg         mdc,
    output reg         mdio_drive_low,
    output reg  [15:0] phy_id1,
    output reg  [15:0] phy_id2,
    output reg  [15:0] phy_status,
    output reg         sample_valid
);

localparam integer HALF_DIV = CLK_HZ / (MDC_HZ * 2);
localparam integer DIV_W = $clog2(HALF_DIV);

reg [DIV_W-1:0] div_cnt;
reg [6:0] bit_index;
reg [1:0] register_index;
reg [15:0] read_shift;
reg [15:0] gap_count;
reg active;

wire [4:0] register_address = (register_index == 2'd0) ? 5'd2 :
                              (register_index == 2'd1) ? 5'd3 : 5'd17;

function automatic drive_zero_for_bit;
    input [6:0] index;
    input [4:0] reg_addr;
    begin
        if (index < 7'd32)
            drive_zero_for_bit = 1'b0;
        else if (index == 7'd32)
            drive_zero_for_bit = 1'b1; // start 01
        else if (index == 7'd33)
            drive_zero_for_bit = 1'b0;
        else if (index == 7'd34)
            drive_zero_for_bit = 1'b0; // read opcode 10
        else if (index == 7'd35)
            drive_zero_for_bit = 1'b1;
        else if ((index >= 7'd36) && (index <= 7'd40))
            drive_zero_for_bit = ~PHY_ADDR[40-index];
        else if ((index >= 7'd41) && (index <= 7'd45))
            drive_zero_for_bit = ~reg_addr[45-index];
        else
            drive_zero_for_bit = 1'b0; // turnaround and data are released
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        div_cnt <= {DIV_W{1'b0}};
        bit_index <= 7'd0;
        register_index <= 2'd0;
        read_shift <= 16'd0;
        gap_count <= 16'd0;
        active <= 1'b0;
        mdc <= 1'b0;
        mdio_drive_low <= 1'b0;
        phy_id1 <= 16'd0;
        phy_id2 <= 16'd0;
        phy_status <= 16'd0;
        sample_valid <= 1'b0;
    end else begin
        sample_valid <= 1'b0;
        if (!active) begin
            mdc <= 1'b0;
            mdio_drive_low <= 1'b0;
            div_cnt <= {DIV_W{1'b0}};
            if (gap_count == POLL_GAP_CYCLES-1) begin
                gap_count <= 16'd0;
                bit_index <= 7'd0;
                read_shift <= 16'd0;
                active <= 1'b1;
            end else begin
                gap_count <= gap_count + 16'd1;
            end
        end else if (div_cnt == HALF_DIV-1) begin
            div_cnt <= {DIV_W{1'b0}};
            if (!mdc) begin
                mdc <= 1'b1;
                if (bit_index >= 7'd48)
                    read_shift <= {read_shift[14:0], mdio_i};
            end else begin
                mdc <= 1'b0;
                if (bit_index == 7'd63) begin
                    active <= 1'b0;
                    mdio_drive_low <= 1'b0;
                    sample_valid <= 1'b1;
                    case (register_index)
                        2'd0: phy_id1 <= read_shift;
                        2'd1: phy_id2 <= read_shift;
                        default: phy_status <= read_shift;
                    endcase
                    register_index <= (register_index == 2'd2) ? 2'd0 : register_index + 2'd1;
                end else begin
                    bit_index <= bit_index + 7'd1;
                    mdio_drive_low <= drive_zero_for_bit(bit_index + 7'd1, register_address);
                end
            end
        end else begin
            div_cnt <= div_cnt + {{(DIV_W-1){1'b0}}, 1'b1};
        end
    end
end

endmodule

`default_nettype wire
