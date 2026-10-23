"""MVID v2: sector-aligned RGB565 frames, optional interleaved PCM, indexed captions.

Existing v1 readers deliberately reject v2. No MP4 decoding happens on the FPGA.
"""
import hashlib
import json
from pathlib import Path
import re
import struct
import wave
import zlib

from PIL import Image, ImageDraw, ImageFont

FRAME_BYTES = 640*480*2
PCM_BYTES = 1600*2*2
PCM_STRIDE = 13*512
CAPTION_BYTES = 1024*64//8

def align(n):
    return (n+511)//512*512

def sha256(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(4*1024*1024), b''):
            h.update(block)
    return h.hexdigest()

def parse_srt(path):
    if path is None:
        return []
    cues=[]
    def ms(value):
        h,m,s,n=map(int,re.split('[:,.]',value))
        return ((h*60+m)*60+s)*1000+n
    text=Path(path).read_text(encoding='utf-8-sig').replace('\r','')
    for block in re.split(r'\n\s*\n',text.strip()):
        lines=block.splitlines()
        k=next((i for i,s in enumerate(lines) if '-->' in s),None)
        if k is None:
            raise ValueError('Subtitle block lacks a timestamp')
        a,b=lines[k].split('-->')
        start,end=ms(a.strip()),ms(b.strip())
        if start<0 or end<=start or (cues and start<cues[-1][1]):
            raise ValueError('Overlapping or invalid subtitles')
        cues.append((start,end,''.join(lines[k+1:]).strip()))
    return cues

def bitmap(text):
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',27)
    image=Image.new('1',(1024,64))
    d=ImageDraw.Draw(image)
    lines=['']
    for ch in text:
        if d.textlength(lines[-1]+ch,font=font)>990:
            lines.append('')
        lines[-1]+=ch
    if len(lines)>2:
        raise ValueError('Subtitle exceeds two lines; split its SRT cue')
    for i,line in enumerate(lines):
        d.text(((1024-d.textlength(line,font=font))/2,i*31),line,font=font,fill=1)
    return image.tobytes()

def header(frames,audio,cue_count,artifact,caption_size):
    record=FRAME_BYTES+(PCM_STRIDE if audio else 0)
    h=bytearray(512)
    struct.pack_into('<4s6H4IQ',h,0,b'MVID',2,512,640,480,30,1,frames,FRAME_BYTES,1,
                     int(audio)|int(cue_count>0)*2,frames*record)
    struct.pack_into('<IIHBBIIQIIII',h,40,record,48000 if audio else 0,1600 if audio else 0,
                     2 if audio else 0,16 if audio else 0,PCM_BYTES if audio else 0,
                     PCM_STRIDE if audio else 0,512+frames*record,cue_count,1000,artifact,caption_size)
    struct.pack_into('<I',h,508,zlib.crc32(h[:508]))
    return h

def parse_header(h,size):
    if len(h)!=512 or h[:4]!=b'MVID' or zlib.crc32(h[:508])!=struct.unpack_from('<I',h,508)[0]:
        raise ValueError('MVID header CRC/magic')
    base=struct.unpack_from('<4s6H4IQ',h)
    _,v,hb,w,ht,fps,den,frames,fb,pix,flags,payload=base
    record,rate,samples,ch,bits,pb,ps,co,cc,tb,aid,cs=struct.unpack_from('<IIHBBIIQIIII',h,40)
    audio=bool(flags&1)
    if (v,hb,w,ht,fps,den,fb,pix)!=(2,512,640,480,30,1,FRAME_BYTES,1) or flags&~3:
        raise ValueError('Unsupported media geometry or version')
    if (rate,samples,ch,bits,pb,ps)!=((48000,1600,2,16,PCM_BYTES,PCM_STRIDE) if audio else (0,0,0,0,0,0)):
        raise ValueError('Invalid audio layout')
    if frames<1 or record!=fb+ps or payload!=frames*record or co!=512+payload or tb!=1000:
        raise ValueError('Invalid frame/section layout')
    if bool(flags&2)!=(cc>0) or aid not in (*range(5),254,255) or any(h[84:508]):
        raise ValueError('Invalid media id/reserved fields')
    if cs!=align(512+cc*16)+cc*CAPTION_BYTES or size!=co+cs or size>=2**32:
        raise ValueError('Truncated, oversized or invalid caption section')
    return dict(format='MVID v2',width=w,height=ht,fps=fps,frames=frames,duration_seconds=frames/fps,
        frame_bytes=fb,record_bytes=record,audio=audio,audio_sample_rate=rate,audio_bytes=pb,
        audio_stride=ps,subtitle_offset=co,subtitle_count=cc,subtitle_timebase=tb,
        subtitle_bytes=cs,artifact_id=aid,file_bytes=size)

def verify(path,hash_file=True):
    path=Path(path)
    with path.open('rb') as f:
        report=parse_header(f.read(512),path.stat().st_size)
        f.seek(report['subtitle_offset'])
        magic,version,count,bits,w,h=struct.unpack('<4sIIIII',f.read(24))
        if (magic,version,count,bits,w,h)!=(b'SUB2',1,report['subtitle_count'],1,1024,64):
            raise ValueError('Invalid caption section')
        last_end=0
        for i in range(count):
            start,end,offset,n=struct.unpack('<4I',f.read(16))
            if start<last_end or end<=start or n!=CAPTION_BYTES or offset!=align(512+count*16)+i*CAPTION_BYTES:
                raise ValueError('Invalid caption index')
            last_end=end
    if hash_file:
        report['sha256']=sha256(path)
    return report

def build(raw,output,*,audio=None,subtitle=None,artifact=0):
    raw,output=Path(raw),Path(output)
    partial=output.with_suffix('.part')
    if output.exists() or partial.exists():
        raise FileExistsError(output)
    with raw.open('rb') as f:
        old=f.read(512)
        if old[:4]!=b'MVID' or struct.unpack_from('<H',old,4)[0]!=1 or zlib.crc32(old[:508])!=struct.unpack_from('<I',old,508)[0]:
            raise ValueError('Expected verified MVID v1 input')
        frames=struct.unpack_from('<I',old,16)[0]
        if struct.unpack_from('<4H',old,8)!=(640,480,30,1) or raw.stat().st_size!=512+frames*FRAME_BYTES:
            raise ValueError('Input dimensions or length')
    cues=parse_srt(subtitle)
    for start,end,_ in cues:
        if end>frames*1000/30:
            raise ValueError('Subtitle extends beyond film')
    section=bytearray(align(512+len(cues)*16)+len(cues)*CAPTION_BYTES)
    struct.pack_into('<4sIIIII',section,0,b'SUB2',1,len(cues),1,1024,64)
    for i,(start,end,text) in enumerate(cues):
        offset=align(512+len(cues)*16)+i*CAPTION_BYTES
        struct.pack_into('<4I',section,24+i*16,start,end,offset,CAPTION_BYTES)
        section[offset:offset+CAPTION_BYTES]=bitmap(text)
    wav=wave.open(str(audio),'rb') if audio else None
    try:
        if wav and (wav.getframerate(),wav.getnchannels(),wav.getsampwidth(),wav.getnframes())!=(48000,2,2,frames*1600):
            raise ValueError('PCM must cover film exactly: 48kHz stereo 16-bit')
        h=header(frames,bool(wav),len(cues),artifact,len(section))
        parse_header(h,512+frames*(FRAME_BYTES+(PCM_STRIDE if wav else 0))+len(section))
        with raw.open('rb') as source,partial.open('xb') as dest:
            dest.write(h);source.seek(512)
            for _ in range(frames):
                pixels=source.read(FRAME_BYTES)
                if len(pixels)!=FRAME_BYTES:
                    raise ValueError('Incomplete frame')
                dest.write(pixels)
                if wav:
                    pcm=wav.readframes(1600)
                    if len(pcm)!=PCM_BYTES:
                        raise ValueError('Incomplete audio block')
                    dest.write(pcm);dest.write(bytes(PCM_STRIDE-PCM_BYTES))
            dest.write(section)
        report=verify(partial)
        partial.rename(output)
        report.update(source_mvid_sha256=sha256(raw),subtitle_sha256=sha256(subtitle) if subtitle else None,
                      audio_sha256=sha256(audio) if audio else None,board_verified=False)
        output.with_suffix('.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        return report
    finally:
        if wav:
            wav.close()

def self_test():
    for audio in (False,True):
        h=header(2,audio,0,0,512)
        parse_header(h,512+2*(FRAME_BYTES+(PCM_STRIDE if audio else 0))+512)
        for at in (0,10,40,60,508):
            bad=bytearray(h);bad[at]^=1
            try:parse_header(bad,512+2*(FRAME_BYTES+(PCM_STRIDE if audio else 0))+512)
            except ValueError:pass
            else:raise AssertionError('Corrupt header accepted')
    assert len(bitmap('副板离线视频字幕自检'))==CAPTION_BYTES
    print('PASS MVID v2 geometry/audio/header CRC/caption checks')

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--self-test',action='store_true')
    p.add_argument('--check',type=Path)
    a=p.parse_args()
    if a.self_test:self_test()
    elif a.check:print(json.dumps(verify(a.check),ensure_ascii=False,indent=2))
    else:p.error('Use --self-test or --check')
