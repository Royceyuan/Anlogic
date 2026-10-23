`timescale 1ns/1ps
`default_nettype none
// Native SD/SDHC read transport. No block-write commands are implemented.
// clk=100 MHz: initialization 400 kHz, default 25 MHz, negotiated HS 50 MHz.
module sd_native_read #(
    parameter integer POWER_CYCLES=1_000_000,
    parameter integer INIT_HALF_PERIOD=125,
    parameter integer DATA_TIMEOUT_CYCLES=10_000_000
)(
    input wire clk,rst_n,read_start,
    input wire [31:0] read_lba,read_blocks,
    output reg sd_clk,
    inout wire sd_cmd,
    input wire [3:0] sd_dat,
    output reg initialized,high_speed,busy,done,
    output wire data_valid,
    output wire [7:0] data,
    output reg [31:0] verified_blocks,
    output reg [7:0] error,
    output wire [7:0] stage
);
localparam POWER=0,IDLE_CLOCKS=1,ISSUE=2,COMMAND_WAIT=3,SELECT_BUSY=4,
           SWITCH_DATA=5,READY=6,READ_DATA=7,STOP_BUSY=8,FAILED=9;
reg [3:0] state;
reg [7:0] phase;
assign stage={state,phase[3:0]};
reg [23:0] power_count,busy_timeout;
reg [7:0] idle_count,divider,current_half;
reg [1:0] clock_mode;
wire [7:0] half_period=clock_mode==0?INIT_HALF_PERIOD:clock_mode==1?2:1;
wire clock_change=current_half!=half_period && !sd_clk;
wire tick_rise=!clock_change&&divider==current_half-1&&!sd_clk;
wire tick_fall=!clock_change&&divider==current_half-1&&sd_clk;
// The forwarded SD clock incurs an output-pad delay. Capture returned data
// half a 100-MHz cycle after its rising edge, then consume it on the next
// core edge. The matching input multicycle describes this enabled sampler.
reg sample_enable,sample_tick,sample_valid;
reg cmd_sample;
reg [3:0] dat_sample;
reg cmd_input;
reg [3:0] dat_input;
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin sample_enable<=0;sample_tick<=0;sample_valid<=0;end
    else begin sample_enable<=tick_rise;sample_tick<=tick_rise;sample_valid<=sample_tick;end
always @(negedge clk) if(sample_enable) begin cmd_sample<=sd_cmd;dat_sample<=sd_dat;end
// Keep the half-cycle I/O path to five plain registers; CRC/state decoding
// then receives a full core cycle rather than sharing that half-cycle path.
always @(posedge clk) begin cmd_input<=cmd_sample;dat_input<=dat_sample;end
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin sd_clk<=0;divider<=0;current_half<=INIT_HALF_PERIOD;end
    else if(clock_change) begin divider<=0;current_half<=half_period;end
    else if(divider==current_half-1) begin divider<=0;sd_clk<=~sd_clk;end
    else divider<=divider+1'b1;
reg cmd_start,cmd_crc;
reg [5:0] cmd_number;
reg [31:0] cmd_argument;
reg [7:0] cmd_length;
wire cmd_o,cmd_oe,cmd_busy,cmd_done;
wire [2:0] cmd_error;
wire [135:0] response;
assign sd_cmd=cmd_oe?cmd_o:1'bz;
sd_native_command u_command(.clk(clk),.rst_n(rst_n),.tick_rise(sample_valid),.tick_fall(tick_fall),
    .start(cmd_start),.command(cmd_number),.argument(cmd_argument),.response_bits(cmd_length),
    .check_crc(cmd_crc),.cmd_i(cmd_input),.cmd_o(cmd_o),.cmd_oe(cmd_oe),
    .busy(cmd_busy),.done(cmd_done),.error(cmd_error),.response(response));
reg data_start,data_cancel,data_continuous;
reg [10:0] block_bytes;
wire rx_busy,rx_valid,block_done;
wire [7:0] rx_data;
wire [9:0] rx_index;
wire [2:0] data_error;
assign data_valid=rx_valid&&(phase==11);
assign data=rx_data;
sd_native_data_rx #(.TIMEOUT_CYCLES(DATA_TIMEOUT_CYCLES)) u_data(
    .clk(clk),.rst_n(rst_n),.tick_rise(sample_valid),.start(data_start),.cancel(data_cancel),
    .continuous(data_continuous),.block_bytes(block_bytes),.dat(dat_input),.busy(rx_busy),
    .valid(rx_valid),.data(rx_data),.byte_index(rx_index),.block_done(block_done),.error(data_error));
reg block_addressed;
reg [15:0] rca;
reg [9:0] init_attempts;
reg [31:0] pending_lba,remaining_blocks;
reg selected_high_speed;
wire r1_error=(response[39:8]&32'hfdffe008)!=0;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=POWER;phase<=0;power_count<=0;busy_timeout<=0;idle_count<=0;clock_mode<=0;
        cmd_start<=0;cmd_crc<=0;cmd_number<=0;cmd_argument<=0;cmd_length<=0;
        data_start<=0;data_cancel<=0;data_continuous<=0;block_bytes<=512;
        initialized<=0;high_speed<=0;busy<=1;done<=0;error<=0;verified_blocks<=0;
        block_addressed<=0;rca<=0;init_attempts<=0;pending_lba<=0;remaining_blocks<=0;
        selected_high_speed<=0;
    end else begin
        cmd_start<=0;data_start<=0;data_cancel<=0;done<=0;
        if(rx_valid&&phase==10&&rx_index==16) selected_high_speed<=rx_data[3:0]==1;
        case(state)
            POWER: if(power_count==POWER_CYCLES-1) begin state<=IDLE_CLOCKS;idle_count<=0;end
                   else power_count<=power_count+1'b1;
            IDLE_CLOCKS: if(tick_rise) begin
                idle_count<=idle_count+1'b1;
                if(idle_count==79) begin phase<=0;state<=ISSUE;end
            end
            ISSUE: if(!cmd_busy) begin
                cmd_start<=1;cmd_length<=48;cmd_crc<=1;state<=COMMAND_WAIT;
                case(phase)
                    0: begin cmd_number<=0;cmd_argument<=0;cmd_length<=0;cmd_crc<=0;end
                    1: begin cmd_number<=8;cmd_argument<=32'h1aa;end
                    2: begin cmd_number<=55;cmd_argument<=0;end
                    3: begin cmd_number<=41;cmd_argument<=32'h40ff8000;cmd_crc<=0;end
                    4: begin cmd_number<=2;cmd_argument<=0;cmd_length<=136;end
                    5: begin cmd_number<=3;cmd_argument<=0;end
                    6: begin cmd_number<=7;cmd_argument<={rca,16'd0};end
                    7: begin cmd_number<=16;cmd_argument<=512;end
                    8: begin cmd_number<=55;cmd_argument<={rca,16'd0};end
                    9: begin cmd_number<=6;cmd_argument<=2;end
                    10: begin
                        cmd_number<=6;cmd_argument<=32'h80fffff1;
                        data_start<=1;data_continuous<=0;block_bytes<=64;selected_high_speed<=0;
                    end
                    11: begin
                        cmd_number<=18;cmd_argument<=block_addressed?pending_lba:pending_lba<<9;
                        data_start<=1;data_continuous<=1;block_bytes<=512;
                    end
                    default:begin cmd_number<=12;cmd_argument<=0;end
                endcase
            end
            COMMAND_WAIT: if(cmd_done) begin
                if(cmd_error!=0) begin error<={1'b0,phase[3:0],cmd_error};state<=FAILED;data_cancel<=1;end
                else if(phase==0) begin phase<=1;state<=ISSUE;end
                else if(phase==1) begin
                    if(response[19:8]!=12'h1aa) begin error<=8'h81;state<=FAILED;end
                    else begin phase<=2;state<=ISSUE;end
                end else if(phase==3) begin
                    if(response[39]) begin block_addressed<=response[38];phase<=4;state<=ISSUE;end
                    else if(init_attempts==1023) begin error<=8'h83;state<=FAILED;end
                    else begin init_attempts<=init_attempts+1'b1;phase<=2;state<=ISSUE;end
                end else if(phase==4) begin phase<=5;state<=ISSUE;end
                else if(phase==5) begin
                    if(response[23:21]!=0 || response[39:24]==0) begin error<=8'h85;state<=FAILED;end
                    else begin rca<=response[39:24];phase<=6;state<=ISSUE;end
                end else if(phase==10 && response[30]) begin
                    // Optional high-speed switch was rejected: stay in default mode.
                    data_cancel<=1;initialized<=1;busy<=0;state<=READY;
                end else if(r1_error) begin error<=8'h80|phase;state<=FAILED;data_cancel<=1;end
                else if(phase==6) begin state<=SELECT_BUSY;busy_timeout<=0;end
                else if(phase==9) begin phase<=10;clock_mode<=1;state<=ISSUE;end
                else if(phase==10) state<=SWITCH_DATA;
                else if(phase==11) state<=READ_DATA;
                else if(phase==12) begin state<=STOP_BUSY;busy_timeout<=0;end
                else begin phase<=phase+1'b1;state<=ISSUE;end
            end
            SELECT_BUSY: begin
                if(sample_valid&&dat_input[0]) begin phase<=block_addressed?8:7;state<=ISSUE;end
                else if(busy_timeout==DATA_TIMEOUT_CYCLES-1) begin error<=8'h86;state<=FAILED;end
                else busy_timeout<=busy_timeout+1'b1;
            end
            SWITCH_DATA: if(block_done) begin
                if(data_error!=0) begin error<=8'h90|data_error;state<=FAILED;end
                else begin
                    high_speed<=selected_high_speed;clock_mode<=selected_high_speed?2:1;
                    initialized<=1;busy<=0;state<=READY;
                end
            end
            READY: if(read_start&&read_blocks!=0) begin
                pending_lba<=read_lba;remaining_blocks<=read_blocks;
                verified_blocks<=0;busy<=1;phase<=11;state<=ISSUE;
            end
            READ_DATA: if(block_done) begin
                if(data_error!=0) begin error<=8'ha0|data_error;state<=FAILED;data_cancel<=1;end
                else begin
                    verified_blocks<=verified_blocks+1'b1;remaining_blocks<=remaining_blocks-1'b1;
                    if(remaining_blocks==1) begin data_cancel<=1;phase<=12;state<=ISSUE;end
                end
            end
            STOP_BUSY: begin
                if(sample_valid&&dat_input[0]) begin state<=READY;busy<=0;done<=1;end
                else if(busy_timeout==DATA_TIMEOUT_CYCLES-1) begin error<=8'h8c;state<=FAILED;end
                else busy_timeout<=busy_timeout+1'b1;
            end
            FAILED:begin busy<=0;data_cancel<=1;end
            default:begin state<=POWER;end
        endcase
    end
end
endmodule
`default_nettype wire
