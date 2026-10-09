`timescale 1ns / 1ps
`default_nettype none
// Electrical-path probe ONLY: connect this board's HDMIA to its HDMIB.
// No PC/monitor, TMDS, EDID slave or external power wiring in this test.
module top_secondary_hdmi_handshake_diag #(
    parameter integer PHASE_CYCLES=25000000,
    parameter integer SETTLE_CYCLES=500000
)(
    input wire clk_50m,key1_n,hdmi_a_hpd,hdmi_b_scl,
    inout wire hdmi_a_scl,hdmi_a_sda,hdmi_b_sda,hdmi_b_hpd,
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
reg [5:0] pins_ff1,pins_ff2;
reg [1:0] hpd_low_sample,hpd_high_sample;
wire hpd_local;
always @(posedge clk_50m) begin
    if(!rst_n) begin heartbeat<=0;pins_ff1<=0;pins_ff2<=0;end
    else begin
        heartbeat<=heartbeat+1'b1;
        pins_ff1<={hpd_local,hdmi_a_hpd,hdmi_a_scl,hdmi_a_sda,hdmi_b_scl,hdmi_b_sda};
        pins_ff2<=pins_ff1;
    end
end
// Open-drain on DDC. Never drive a high or connect connector 5V to FPGA GPIO.
// Read the physical output PAD, not just the internal high request. Verify
// mapped BI PAD/diq after synthesis so optimization cannot fake this check.
EG_LOGIC_IOTRIBUF u_hpd_pad(.i(rst_n && (done || phase!=0)),.t(1'b0),
    .o(hpd_local),.io(hdmi_b_hpd));
assign hdmi_a_scl=rst_n && !done && phase==3 ? 1'b0 : 1'bz;
assign hdmi_a_sda=rst_n && !done && phase==5 ? 1'b0 : 1'bz;
assign hdmi_b_sda=rst_n && !done && phase==6 ? 1'b0 : 1'bz;
reg matches;
always @* begin
    case(phase)
        0:matches=!pins_ff2[5]&&!pins_ff2[4];         // HPD low, B->A
        1:matches=pins_ff2[5]&&pins_ff2[4];           // HPD high, B->A
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
        hpd_low_sample<=0;hpd_high_sample<=0;
    end else if(!done) begin
        if(phase_cycles>=SETTLE_CYCLES) begin
            phase_ok<=phase_ok&&matches;
            // Freeze the first failure, or the last good sample if no failure.
            if(phase_ok && phase==0) hpd_low_sample<=pins_ff2[5:4];
            if(phase_ok && phase==1) hpd_high_sample<=pins_ff2[5:4];
        end
        if(phase_cycles==PHASE_CYCLES-1) begin
            passed[phase]<=phase_ok&&matches;
            phase_cycles<=0;phase_ok<=1;
            if(phase==7) done<=1;
            else phase<=phase+1'b1;
        end else phase_cycles<=phase_cycles+1'b1;
    end
end
reg [15:0] value;
always @* begin
    if(!done) value={4'hd,1'b0,phase,1'b0,pins_ff2[4:2],1'b0,pins_ff2[5],pins_ff2[1:0]};
    else case(heartbeat[26:25])
        1:value={8'he0,3'b000,hpd_low_sample[1],3'b000,hpd_low_sample[0]};
        2:value={8'he1,3'b000,hpd_high_sample[1],3'b000,hpd_high_sample[0]};
        default:value={8'hf0,passed};
    endcase
end
seg_hex_display u_seg(.clk(clk_50m),.rst_n(rst_n),.value(value),
    .seg_data(seg_data),.seg_sel(seg_sel));
assign led={done&&(&passed[6:2]),done&&(&passed[1:0]),done,heartbeat[24]};
endmodule
`default_nettype wire
