"""Compile the actual top-level OSD expressions, not a duplicate decoder."""
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'_build_offline_integration'


def main():
    source=(ROOT/'src/secondary/top_secondary_offline_av.v').read_text()
    expressions='\n'.join(re.search(r'wire [^;]*\b'+name+r'=[^;]+;',source).group() for name in ('lecture_now','main_state'))
    bench='''module tb;
reg status_seen=0,show_emergency=0,manual_reported=0;
reg [127:0] heartbeat_data=0;
EXPRESSION
task expect_state;input [3:0] value;begin #1;if(main_state!==value)$fatal(1,"OSD state got %d expected %d",main_state,value);end endtask
initial begin
expect_state(0);status_seen=1;heartbeat_data[127:120]=1;
heartbeat_data[71]=1;expect_state(1);
heartbeat_data[69]=1;expect_state(2);
heartbeat_data[71]=0;expect_state(2);
heartbeat_data[127:120]=2;heartbeat_data[119:112]=0;heartbeat_data[111:104]=0;
heartbeat_data[103:96]=1;expect_state(4);
heartbeat_data[103:96]=2;expect_state(5);
heartbeat_data[103:96]=1;heartbeat_data[68]=1;expect_state(5);
heartbeat_data[68]=0;heartbeat_data[103:96]=5;manual_reported=1;expect_state(3);
heartbeat_data[103:96]=3;expect_state(3);
heartbeat_data[127:120]=1;heartbeat_data[69]=0;expect_state(1);
heartbeat_data[70]=1;expect_state(6);
heartbeat_data[127:120]=4;expect_state(8);
show_emergency=1;expect_state(7);
show_emergency=0;heartbeat_data=0;expect_state(0);
$display("PASS actual OSD decoder: bit71 is validity, bit69 is preload; overview/manual/lecture/pause/recovery/error/emergency");$finish;
end endmodule
'''.replace('EXPRESSION',expressions)
    BUILD.mkdir(exist_ok=True)
    path=BUILD/'actual_osd_state.v';path.write_text(bench)
    binary=BUILD/'actual_osd_state.vvp'
    subprocess.run(['D:/iverilog/bin/iverilog.exe','-g2012','-s','tb','-o',str(binary),str(path)],check=True)
    result=subprocess.run(['D:/iverilog/bin/vvp.exe',str(binary)],capture_output=True,text=True,check=True)
    assert 'PASS' in result.stdout
    (BUILD/'offline_main_state.log').write_text(result.stdout)
    print(result.stdout,end='')


if __name__=='__main__':main()
