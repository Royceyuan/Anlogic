`timescale 1ns/1ps
`default_nettype none
// Read-only FAT32 root VIDEO0.BIN, MVID v1 RGB565-BE. Each frame is
// provisional until frame_done: a transport CRC error must never publish it.
module fat32_mvid_reader #(
    parameter integer WIDTH=640,HEIGHT=360
)(
    input wire clk,rst_n,card_ready,next_frame,
    output reg sd_start,
    output reg [31:0] sd_lba,sd_blocks,
    input wire sd_done,sd_valid,
    input wire [7:0] sd_data,sd_error,
    output wire byte_valid,
    output wire [7:0] byte_data,
    output reg ready,frame_busy,frame_done,
    output reg [31:0] frame_index,frame_count,
    output reg [7:0] error,
    output wire [7:0] stage
);
localparam integer FRAME_BYTES=WIDTH*HEIGHT*2,FRAME_SECTORS=FRAME_BYTES/512;
localparam WAIT_CARD=0,REQUEST=1,TRANSFER=2,BOOT_CHECK=3,ROOT_NEXT=4,
    FAT_CHECK=5,HEADER_CHECK=6,READY=7,RUN=8,FAILED=9,LAYOUT_CHECK=10,
    HEADER_CALC=11,HEADER_COMMIT=12,GEOMETRY_SUB=13,GEOMETRY_SHIFT=14,GEOMETRY_END=15;
localparam BOOT=0,ROOT=1,FAT=2,HEADER=3,PIXELS=4;
reg [3:0] state;
reg [2:0] operation;
reg [1:0] address_step;
reg [31:0] address_work,last_frame_index;
assign stage={state,1'b0,operation};
reg [18:0] received,expected;
wire [8:0] offset=received[8:0];
reg [31:0] volume,partition,fat_start,data_start,total_sectors,sectors_per_fat;
reg [15:0] bytes_per_sector,reserved,root_entries,fat16,signature,ext_flags;
reg [7:0] sectors_per_cluster,num_fats,jump,partition_type;
reg [3:0] cluster_shift;
reg [31:0] root_cluster,current_cluster,first_cluster,file_size,fat_next,max_cluster;
reg [7:0] cluster_sector;
reg [12:0] root_scanned;
reg fat_for_root,found,end_directory,name_match,deleted;
reg [7:0] attr;
reg [31:0] entry_cluster,entry_size;
reg [31:0] sectors_left;
reg [31:0] header_magic,header_frames,header_frame_bytes,header_format,header_flags;
reg [15:0] header_version,header_size,header_width,header_height,header_fps_n,header_fps_d;
reg [63:0] header_payload;
reg [31:0] header_crc,computed_crc;
reg reserved_bad;
reg [63:0] checked_payload;
reg header_ok,length_ok;
reg [31:0] checked_fat_span;
reg [32:0] volume_end,layout_end;
wire [63:0] extended_frames={32'd0,header_frames};
wire [63:0] payload_size=FRAME_BYTES==460800?
    (extended_frames<<19)-(extended_frames<<16)+(extended_frames<<11):extended_frames*FRAME_BYTES;
wire [31:0] fat_span=num_fats==2?sectors_per_fat<<1:sectors_per_fat;
wire [31:0] cluster_available=sectors_per_cluster-cluster_sector;
wire [31:0] run_blocks=sectors_left<cluster_available?sectors_left:cluster_available;
wire [8:0] fat_offset={current_cluster[6:0],2'b00};
assign byte_valid=state==TRANSFER&&operation==PIXELS&&sd_valid&&received<expected&&error==0&&sd_error==0;
assign byte_data=sd_data;
function [7:0] name_byte;
    input [3:0] index;
    begin case(index)
        0:name_byte="V";1:name_byte="I";2:name_byte="D";3:name_byte="E";4:name_byte="O";
        5:name_byte="0";6,7:name_byte=" ";8:name_byte="B";9:name_byte="I";default:name_byte="N";
    endcase end
endfunction
function [3:0] log_cluster;
    input [7:0] n;
    begin case(n)
        1:log_cluster=0;2:log_cluster=1;4:log_cluster=2;8:log_cluster=3;
        16:log_cluster=4;32:log_cluster=5;64:log_cluster=6;128:log_cluster=7;
        default:log_cluster=15;
    endcase end
endfunction
function [31:0] crc32_byte;
    input [31:0] crc;
    input [7:0] value;
    reg [31:0] c;
    integer bit_index;
    begin
        c=crc^value;
        for(bit_index=0;bit_index<8;bit_index=bit_index+1)
            c=(c>>1)^(c[0]?32'hedb88320:0);
        crc32_byte=c;
    end
endfunction
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=WAIT_CARD;operation<=BOOT;address_step<=0;address_work<=0;last_frame_index<=0;
        sd_start<=0;sd_lba<=0;sd_blocks<=1;
        ready<=0;frame_busy<=0;frame_done<=0;frame_index<=0;frame_count<=0;error<=0;
        received<=0;expected<=512;volume<=0;partition<=0;fat_start<=0;data_start<=0;
        total_sectors<=0;sectors_per_fat<=0;bytes_per_sector<=0;reserved<=0;num_fats<=0;
        root_entries<=0;fat16<=0;signature<=0;ext_flags<=0;jump<=0;partition_type<=0;
        sectors_per_cluster<=0;cluster_shift<=0;root_cluster<=0;current_cluster<=0;
        first_cluster<=0;file_size<=0;fat_next<=0;max_cluster<=0;cluster_sector<=0;root_scanned<=0;
        fat_for_root<=0;found<=0;end_directory<=0;name_match<=0;deleted<=0;attr<=0;
        entry_cluster<=0;entry_size<=0;sectors_left<=0;header_magic<=0;header_frames<=0;
        header_frame_bytes<=0;header_format<=0;header_flags<=0;header_version<=0;header_size<=0;
        header_width<=0;header_height<=0;header_fps_n<=0;header_fps_d<=0;header_payload<=0;
        header_crc<=0;computed_crc<=32'hffffffff;reserved_bad<=0;
        checked_payload<=0;header_ok<=0;length_ok<=0;checked_fat_span<=0;volume_end<=0;layout_end<=0;
    end else begin
        sd_start<=0;frame_done<=0;
        if(state!=REQUEST)address_step<=0;
        if(sd_error!=0) begin error<=8'he0;state<=FAILED;ready<=0;frame_busy<=0;end
        else case(state)
            WAIT_CARD: if(card_ready) begin operation<=BOOT;sd_lba<=0;state<=REQUEST;end
            REQUEST: begin
                // Cluster subtraction, variable shift and LBA additions each
                // get one core cycle. No combinational multi-adder SD path.
                if(operation==ROOT||operation==HEADER||operation==PIXELS)begin
                    address_step<=address_step+1'b1;
                    case(address_step)
                        0:address_work<=current_cluster-2;
                        1:address_work<=address_work<<cluster_shift;
                        2:address_work<=address_work+data_start;
                        3:begin sd_lba<=address_work+cluster_sector;
                            received<=0;expected<=sd_blocks<<9;sd_start<=1;state<=TRANSFER;end
                    endcase
                end else begin received<=0;expected<=sd_blocks<<9;sd_start<=1;state<=TRANSFER;end
            end
            TRANSFER: begin
                if(sd_valid&&received<expected) begin
                    received<=received+1'b1;
                    case(operation)
                        BOOT: begin
                            case(offset)
                                0:jump<=sd_data;
                                11,12:bytes_per_sector[(offset-11)*8+:8]<=sd_data;
                                13:sectors_per_cluster<=sd_data;
                                14,15:reserved[(offset-14)*8+:8]<=sd_data;
                                16:num_fats<=sd_data;
                                17,18:root_entries[(offset-17)*8+:8]<=sd_data;
                                22,23:fat16[(offset-22)*8+:8]<=sd_data;
                                32,33,34,35:total_sectors[(offset-32)*8+:8]<=sd_data;
                                36,37,38,39:sectors_per_fat[(offset-36)*8+:8]<=sd_data;
                                40,41:ext_flags[(offset-40)*8+:8]<=sd_data;
                                44,45,46,47:root_cluster[(offset-44)*8+:8]<=sd_data;
                                450:partition_type<=sd_data;
                                454,455,456,457:partition[(offset-454)*8+:8]<=sd_data;
                                510,511:signature[(offset-510)*8+:8]<=sd_data;
                            endcase
                        end
                        ROOT: begin
                            case(offset[4:0])
                                0:begin
                                    name_match<=sd_data=="V";deleted<=sd_data==0||sd_data==8'he5;
                                    if(sd_data==0) end_directory<=1;
                                end
                                1,2,3,4,5,6,7,8,9,10:name_match<=name_match&&sd_data==name_byte(offset[3:0]);
                                11:attr<=sd_data;
                                20:entry_cluster[23:16]<=sd_data;
                                21:entry_cluster[31:24]<=sd_data;
                                26:entry_cluster[7:0]<=sd_data;
                                27:entry_cluster[15:8]<=sd_data;
                                28,29,30:entry_size[(offset[4:0]-28)*8+:8]<=sd_data;
                                31:if(!found&&!end_directory&&name_match&&!deleted&&(attr&8'h18)==0&&attr!=8'h0f) begin
                                    found<=1;first_cluster<=entry_cluster&32'h0fffffff;
                                    file_size<={sd_data,entry_size[23:0]};
                                end
                            endcase
                        end
                        FAT:if(offset>=fat_offset&&offset<fat_offset+4)
                            fat_next[(offset-fat_offset)*8+:8]<=sd_data;
                        HEADER:begin
                            if(offset<508) computed_crc<=crc32_byte(computed_crc,sd_data);
                            if(offset>=40&&offset<508&&sd_data!=0) reserved_bad<=1;
                            case(offset)
                                0,1,2,3:header_magic[offset*8+:8]<=sd_data;
                                4,5:header_version[(offset-4)*8+:8]<=sd_data;
                                6,7:header_size[(offset-6)*8+:8]<=sd_data;
                                8,9:header_width[(offset-8)*8+:8]<=sd_data;
                                10,11:header_height[(offset-10)*8+:8]<=sd_data;
                                12,13:header_fps_n[(offset-12)*8+:8]<=sd_data;
                                14,15:header_fps_d[(offset-14)*8+:8]<=sd_data;
                                16,17,18,19:header_frames[(offset-16)*8+:8]<=sd_data;
                                20,21,22,23:header_frame_bytes[(offset-20)*8+:8]<=sd_data;
                                24,25,26,27:header_format[(offset-24)*8+:8]<=sd_data;
                                28,29,30,31:header_flags[(offset-28)*8+:8]<=sd_data;
                                32,33,34,35,36,37,38,39:header_payload[(offset-32)*8+:8]<=sd_data;
                                508,509,510,511:header_crc[(offset-508)*8+:8]<=sd_data;
                            endcase
                        end
                    endcase
                end
                if(sd_done) begin
                    if(received!=expected) begin error<=8'h01;state<=FAILED;end
                    else case(operation)
                        BOOT:state<=BOOT_CHECK;
                        ROOT:state<=ROOT_NEXT;
                        FAT:state<=FAT_CHECK;
                        HEADER:state<=HEADER_CALC;
                        PIXELS:begin
                            cluster_sector<=cluster_sector+sd_blocks;
                            sectors_left<=sectors_left-sd_blocks;
                            if(sectors_left==sd_blocks) begin
                                frame_busy<=0;frame_done<=1;state<=READY;
                            end else state<=RUN;
                        end
                    endcase
                end
            end
            BOOT_CHECK:begin
                if(signature!=16'haa55) begin error<=8'h02;state<=FAILED;end
                else if((jump==8'heb||jump==8'he9)&&bytes_per_sector==512&&root_entries==0&&fat16==0&&
                    log_cluster(sectors_per_cluster)!=15&&reserved!=0&&(num_fats==1||num_fats==2)&&
                    sectors_per_fat!=0&&root_cluster>=2&&root_cluster<32'h0ffffff0&&total_sectors!=0&&
                    (ext_flags[7]==0||ext_flags[3:0]<num_fats)) begin
                    cluster_shift<=log_cluster(sectors_per_cluster);
                    fat_start<=volume+reserved;checked_fat_span<=fat_span;
                    volume_end<={1'b0,volume}+{1'b0,total_sectors};
                    max_cluster<=total_sectors-reserved;
                    current_cluster<=root_cluster;cluster_sector<=0;state<=GEOMETRY_SUB;
                end else if(volume==0&&partition!=0&&
                    (partition_type==8'h0b||partition_type==8'h0c||partition_type==8'h1b||partition_type==8'h1c)) begin
                    volume<=partition;sd_lba<=partition;state<=REQUEST;
                end else begin error<=8'h03;state<=FAILED;end
            end
            ROOT_NEXT:begin
                if(found) begin
                    if(first_cluster<2||first_cluster>max_cluster||file_size<512+FRAME_BYTES) begin error<=8'h04;state<=FAILED;end
                    else begin current_cluster<=first_cluster;cluster_sector<=0;operation<=HEADER;state<=REQUEST;end
                end else if(end_directory||root_scanned==4096) begin error<=8'h05;state<=FAILED;end
                else if(operation==ROOT&&cluster_sector+1==sectors_per_cluster) begin
                    fat_for_root<=1;operation<=FAT;sd_lba<=fat_start+(current_cluster>>7);fat_next<=0;state<=REQUEST;
                end else begin
                    operation<=ROOT;root_scanned<=root_scanned+1'b1;
                    if(operation==ROOT)cluster_sector<=cluster_sector+1'b1;
                    state<=REQUEST;
                end
            end
            FAT_CHECK:begin
                if(fat_next[27:0]<2||fat_next[27:0]>=28'hffffff0||fat_next[27:0]>max_cluster||
                    fat_next[27:0]==current_cluster[27:0]) begin
                    error<=8'h06;state<=FAILED;
                end else begin
                    current_cluster<={4'd0,fat_next[27:0]};cluster_sector<=0;
                    state<=fat_for_root?ROOT_NEXT:RUN;
                end
            end
            HEADER_CALC:begin
                checked_payload<=payload_size;
                header_ok<=!(header_magic!=32'h4449564d||header_version!=1||header_size!=512||header_width!=WIDTH||
                    header_height!=HEIGHT||header_fps_n!=30||header_fps_d!=1||header_frames==0||
                    header_frame_bytes!=FRAME_BYTES||header_format!=1||header_flags!=0||reserved_bad||
                    header_crc!=~computed_crc);
                state<=HEADER_CHECK;
            end
            HEADER_CHECK:begin
                length_ok<=header_payload==checked_payload&&checked_payload+512=={32'd0,file_size};
                state<=HEADER_COMMIT;
            end
            HEADER_COMMIT:begin
                if(!header_ok||!length_ok)begin error<=8'h07;state<=FAILED;end
                else begin frame_count<=header_frames;last_frame_index<=header_frames-1'b1;
                    cluster_sector<=1;ready<=1;state<=READY;end
            end
            READY:if(next_frame) begin frame_busy<=1;sectors_left<=FRAME_SECTORS;state<=RUN;end
            RUN:begin
                if(cluster_sector==sectors_per_cluster) begin
                    fat_for_root<=0;operation<=FAT;sd_lba<=fat_start+(current_cluster>>7);sd_blocks<=1;
                    fat_next<=0;state<=REQUEST;
                end else begin
                    operation<=PIXELS;sd_blocks<=run_blocks;state<=REQUEST;
                end
            end
            LAYOUT_CHECK:begin
                if(volume_end[32]||layout_end[32]||layout_end>=volume_end||max_cluster<2||
                    max_cluster>=32'h0ffffff0||root_cluster>max_cluster||
                    ((max_cluster>>7)>=sectors_per_fat))begin error<=8'h08;state<=FAILED;end
                else state<=ROOT_NEXT;
            end
            GEOMETRY_SUB:begin
                layout_end<={1'b0,fat_start}+{1'b0,checked_fat_span};
                data_start<=fat_start+checked_fat_span;
                fat_start<=fat_start+(ext_flags[7]&&ext_flags[0]?sectors_per_fat:0);
                max_cluster<=max_cluster-checked_fat_span;state<=GEOMETRY_SHIFT;
            end
            GEOMETRY_SHIFT:begin max_cluster<=max_cluster>>cluster_shift;state<=GEOMETRY_END;end
            GEOMETRY_END:begin max_cluster<=max_cluster+1'b1;state<=LAYOUT_CHECK;end
            FAILED:begin ready<=0;frame_busy<=0;end
        endcase
        // Advance only after the consumer has observed the completed frame.
        if(frame_done) begin
            sd_blocks<=1;
            if(frame_index==last_frame_index) begin frame_index<=0;current_cluster<=first_cluster;cluster_sector<=1;end
            else frame_index<=frame_index+1'b1;
        end
    end
end
endmodule
`default_nettype wire
