"""Small fixed 16x16 Chinese OSD font and pre-encoded status lines."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
LINK=['双板通信：等待连接','双板通信：在线','通信中断 · 以下为最后已知']
STATE=['主板状态：等待状态','主板状态：总览','主板状态：预加载',
       '主板状态：手动浏览','主板状态：自动讲解 · 播放中','主板状态：自动讲解 · 暂停',
       '主板状态：恢复中','主板状态：应急','主板状态：媒体异常']
NAMES=['越王勾践剑','四羊方尊','金缕玉衣','铜奔马','长信宫灯','—']
EMERGENCY=['应急疏散指引','保持冷静  沿现场疏散指示有序撤离','请勿乘坐电梯  不推挤  不逆行']
VIDEO=['源视频：未就绪','源视频：640×480 · 30fps']

def main():
    names=[f'文物：{name} · 主讲{speed}×' for name in NAMES for speed in range(1,4)]
    texts=LINK+STATE+names+EMERGENCY+VIDEO
    chars=' '+''.join(sorted(set(''.join(texts))-{' '}))
    assert len(chars)<=128
    ids={c:i for i,c in enumerate(chars)}
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
    words=[]
    for c in chars:
        tile=Image.new('L',(16,16));box=font.getbbox(c)
        ImageDraw.Draw(tile).text(((16-(box[2]-box[0]))//2-box[0],(16-(box[3]-box[1]))//2-box[1]),c,font=font,fill=255)
        words.extend(sum((tile.getpixel((x,y))>=112)<<(15-x) for x in range(16)) for y in range(16))
    words.extend([0]*(2048-len(words)))
    def packed(text):
        assert len(text)<=24,text
        return sum(ids[c]<<(7*i) for i,c in enumerate(text))
    lines=['// Generated fixed vocabulary, one BRAM32K; no general-purpose font.',
        'function [255:0] offline_font_init; input [6:0] index; begin case(index)']
    for i in range(128):lines.append(f"7'd{i}:offline_font_init=256'h{sum(words[i*16+j]<<(16*j) for j in range(16)):064x};")
    lines+=['endcase end endfunction','function [167:0] offline_line;',
        'input [2:0] row; input [23:0] status; begin offline_line=0; case(row)',
        '0:case(status[5:4])']
    for i,t in enumerate(LINK):lines.append(f"2'd{i}:offline_line=168'h{packed(t):042x};")
    lines+=['default:offline_line=0;endcase','1:case(status[9:6])']
    for i,t in enumerate(STATE):lines.append(f"4'd{i}:offline_line=168'h{packed(t):042x};")
    lines+=['default:offline_line=0;endcase','2:case({status[12:10],status[14:13]})']
    for i,name in enumerate(NAMES):
        for speed in range(3):
            key=((i if i<5 else 7)<<2)|speed
            lines.append(f"5'd{key}:offline_line=168'h{packed(f'文物：{name} · 主讲{speed+1}×'):042x};")
    lines+=['default:offline_line=0;endcase']
    for i,t in enumerate(EMERGENCY,3):lines.append(f"{i}:offline_line=168'h{packed(t):042x};")
    lines.append(f"6:offline_line=status[17]?168'h{packed(VIDEO[1]):042x}:168'h{packed(VIDEO[0]):042x};")
    lines+=['default:offline_line=0;endcase end endfunction']
    # Native primitive initialization, identical packing to the existing help font.
    lines+=['module secondary_offline_font(input wire clk,input wire [10:0] address,output wire [15:0] data);',
        '`ifdef SIM','reg [15:0] q; always @(posedge clk) q<=offline_font_init(address[10:4]) >> {address[3:0],4\'b0000};',
        'assign data=q;','`else','EG_PHY_BRAM32K #(.MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),',
        '.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),']
    for i in range(128):lines.append(f".INIT_{i:02X}(offline_font_init(7'd{i})){',' if i<127 else ''}")
    lines+=[') u_font(.doa(data),.dia(16\'d0),.addra(address),.bytea(1\'b0),.bytewea(1\'b0),',
        '.csa(1\'b1),.wea(1\'b0),.clka(clk),.rsta(1\'b0),.ocea(1\'b1),',
        '.dob(),.dib(16\'d0),.addrb(11\'d0),.byteb(1\'b0),.byteweb(1\'b0),',
        '.csb(1\'b0),.web(1\'b0),.clkb(clk),.rstb(1\'b0),.oceb(1\'b0));','`endif','endmodule']
    # Functions are included inside both the overlay and font module. Keep
    # module declarations separate so the Verilog remains legal in all tools.
    split=next(i for i,line in enumerate(lines) if line.startswith('module secondary_offline_font'))
    (ROOT/'src/secondary/secondary_offline_font.vh').write_text('\n'.join(lines[:split])+'\n',encoding='utf-8')
    body=lines[split:];body.insert(1,'`include "src/secondary/secondary_offline_font.vh"')
    (ROOT/'src/secondary/secondary_offline_font.v').write_text('`timescale 1ns/1ps\n`default_nettype none\n'+'\n'.join(body)+'\n`default_nettype wire\n',encoding='utf-8')
    print(f'PASS fixed font: {len(chars)} glyphs, one 32K block, maximum line {max(map(len,texts))} cells')

if __name__=='__main__':main()
