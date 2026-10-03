`timescale 1ns/1ps
module tb_source_row_hit;
reg in_picture=0,display_epoch=0;
reg [2:0] slot_valid=0,slot_epoch=0;
reg [9:0] slot_tag0=0,slot_tag1=0,slot_tag2=0;
reg signed [10:0] mapped_y=0;
wire hit,ref_hit;
wire [1:0] slot,ref_slot;
reg test_pass=0;
integer row, matches, controls, trial, bit_index, checks=0;
row_hit_candidate dut(in_picture,display_epoch,slot_valid,slot_epoch,
    slot_tag0,slot_tag1,slot_tag2,mapped_y,hit,slot);
row_hit_reference ref_dut(in_picture,display_epoch,slot_valid,slot_epoch,
    slot_tag0,slot_tag1,slot_tag2,mapped_y,ref_hit,ref_slot);
task check;
begin
    #1;
    if({hit,slot} !== {ref_hit,ref_slot})
        $fatal(1,"row hit/priority mismatch y=%0d valid=%b epoch=%b",mapped_y,slot_valid,slot_epoch);
    checks=checks+1;
end
endtask
initial begin
    // Every 10-bit row, equality combination, valid/epoch mask, visible flag.
    for(row=0;row<1024;row=row+1)
      for(matches=0;matches<8;matches=matches+1)
        for(controls=0;controls<256;controls=controls+1) begin
            mapped_y=row;
            slot_tag0=matches[0] ? row : (row+1);
            slot_tag1=matches[1] ? row : (row+1);
            slot_tag2=matches[2] ? row : (row+1);
            {in_picture,display_epoch,slot_valid,slot_epoch}=controls[7:0];
            check;
        end
    // X/Z must not change the old priority merge semantics either.
    for(trial=0;trial<65536;trial=trial+1) begin
        {in_picture,display_epoch,slot_valid,slot_epoch}=8'd0;
        for(bit_index=0;bit_index<8;bit_index=bit_index+1)
            case((trial>>(2*bit_index))&3)
              0:{in_picture,display_epoch,slot_valid,slot_epoch}=
                  {in_picture,display_epoch,slot_valid,slot_epoch}&~(8'd1<<bit_index);
              1:{in_picture,display_epoch,slot_valid,slot_epoch}=
                  {in_picture,display_epoch,slot_valid,slot_epoch}|(8'd1<<bit_index);
              2: begin
                  if(bit_index<3) slot_epoch[bit_index]=1'bx;
                  else if(bit_index<6) slot_valid[bit_index-3]=1'bx;
                  else if(bit_index==6) display_epoch=1'bx; else in_picture=1'bx;
              end
              3: begin
                  if(bit_index<3) slot_epoch[bit_index]=1'bz;
                  else if(bit_index<6) slot_valid[bit_index-3]=1'bz;
                  else if(bit_index==6) display_epoch=1'bz; else in_picture=1'bz;
              end
            endcase
        mapped_y=10'd539; slot_tag0=10'd539; slot_tag1=10'd539; slot_tag2=10'd539;
        check;
    end
    test_pass=1;
    $display("PASS source row hit: %0d comparisons, all rows/matches/valid/epoch/priority and X/Z controls",checks);
    $finish;
end
endmodule
