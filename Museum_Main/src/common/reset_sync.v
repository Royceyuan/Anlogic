`timescale 1ns / 1ps
`default_nettype none

module reset_sync #(
    parameter PRESERVE = "false"
) (
    input  wire clk,
    input  wire arst_n,
    output wire srst_n
);

(* preserve = PRESERVE *) reg [1:0] rst_ff = 2'b00;

always @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
        rst_ff <= 2'b00;
    end else begin
        rst_ff <= {rst_ff[0], 1'b1};
    end
end

assign srst_n = rst_ff[1];

endmodule

`default_nettype wire
