# Keep the failed candidate outside the product RTL. Callers set root.
set out $root/_build_mbp1_crc_candidate
file mkdir $out
set fd [open $root/src/ethernet/mbp1_codec.v r]
set codec [read $fd]
close $fd
set first [string first {function [15:0] crc_byte;} $codec]
set last [string first endfunction $codec $first]
if {$first<0 || $last<$first} {error "CRC function anchor changed"}
set folded_crc {function [15:0] crc_byte;
    input [15:0] prior;
    input [7:0] value;
    reg [7:0] folded;
    begin
        folded = prior[15:8] ^ value;
        folded = folded ^ (folded >> 4);
        crc_byte = {prior[7:0],8'd0} ^ {folded[3:0],12'd0} ^
                   {3'd0,folded,5'd0} ^ {8'd0,folded};
    end
endfunction}
set candidate $out/mbp1_codec_folded.v
set fd [open $candidate w]
puts -nonewline $fd [string replace $codec $first [expr {$last+10}] $folded_crc]
close $fd
