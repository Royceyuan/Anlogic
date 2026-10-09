`timescale 1ns / 1ps
`default_nettype none
// Electrical-path probe ONLY: connect this board's HDMIA to its HDMIB.
// No PC/monitor, TMDS, EDID slave or external power wiring in this test.
module top_secondary_hdmi_handshake_diag #(
    parameter integer PHASE_CYCLES=25000000,
    parameter integer SETTLE_CYCLES=500000
)(
    input wire clk_50m,key1_n,hdmi_a_hpd,hdmi_b_scl,
    inout wire hdmi_a_scl,hdmi_a_sda,hdmi_b_sda,
    output wire hdmi_b_hpd,
    output wire [3:0] led,
    output wire [7:0] seg_data,seg_sel
);
reg [15:0] startup=0;
always @(posedge clk_50m) if(startup!=16'hffff) startup<=startup+1'b1;
wire rst_n=&startup;
wire [3:0] key_press;
key_debounce u_keys(.clk(clk_50m),.rst_n(rst_n),.key_n({3'b111,key1_n}),
    .key_level_n(),.key_press_pulse(key_press),.key_release_pulse());
reg [26:0] heartbeat;
reg [24:0] phase_cycles;
reg [2:0] phase;
reg [7:0] passed;
reg done,phase_ok;
reg [4:0] pins_ff1,pins_ff2;
always @(posedge clk_50m) begin
    if(!rst_n) begin heartbeat<=0;pins_ff1<=0;pins_ff2<=0;end
    else begin
        heartbeat<=heartbeat+1'b1;
        pins_ff1<={hdmi_a_hpd,hdmi_a_scl,hdmi_a_sda,hdmi_b_scl,hdmi_b_sda};
        pins_ff2<=pins_ff1;
    end
end
// Open-drain on DDC. Never drive a high or connect connector 5V to FPGA GPIO.
assign hdmi_b_hpd=rst_n && (done || phase!=0);
assign hdmi_a_scl=rst_n && !done && phase==3 ? 1'b0 : 1'bz;
assign hdmi_a_sda=rst_n && !done && phase==5 ? 1'b0 : 1'bz;
assign hdmi_b_sda=rst_n && !done && phase==6 ? 1'b0 : 1'bz;
reg matches;
always @* begin
    case(phase)
        0:matches=!pins_ff2[4];                      // HPD low, B->A
        1:matches=pins_ff2[4];                       // HPD high, B->A
        2:matches=pins_ff2[3]&&pins_ff2[1];           // SCL released
        3:matches=!pins_ff2[3]&&!pins_ff2[1];         // SCL low, A->B
        4:matches=pins_ff2[2]&&pins_ff2[0];           // SDA released
        5,6:matches=!pins_ff2[2]&&!pins_ff2[0];       // SDA low, both directions
        default:matches=&pins_ff2;                   // All released, HPD high
    endcase
end
always @(posedge clk_50m) begin
    if(!rst_n || key_press[0]) begin
        phase_cycles<=0;phase<=0;passed<=0;done<=0;phase_ok<=1;
    end else if(!done) begin
        if(phase_cycles>=SETTLE_CYCLES) phase_ok<=phase_ok&&matches;
        if(phase_cycles==PHASE_CYCLES-1) begin
            passed[phase]<=phase_ok&&matches;
            phase_cycles<=0;phase_ok<=1;
            if(phase==7) done<=1;
            else phase<=phase+1'b1;
        end else phase_cycles<=phase_cycles+1'b1;
    end
end
wire [15:0] value=done ? {8'hf0,passed} :
    {4'hd,1'b0,phase,1'b0,pins_ff2[4:2],2'b00,pins_ff2[1:0]};
seg_hex_display u_seg(.clk(clk_50m),.rst_n(rst_n),.value(value),
    .seg_data(seg_data),.seg_sel(seg_sel));
assign led={done&&(&passed[7:2]),done&&(&passed[1:0]),done,heartbeat[24]};
endmodule
`default_nettype wire
