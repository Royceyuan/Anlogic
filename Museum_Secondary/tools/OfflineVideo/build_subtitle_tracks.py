"""Build local MSUB v3 resources using the main-board formatter and sample clock.

No TF access. SRT timestamps are preserved, never fitted to the video length.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import wave

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]
MEDIA=REPO/'assets'
NAMES=['01_越王勾践剑','02_四羊方尊','03_金缕玉衣','04_铜奔马','05_长信宫灯','06_总览宣传片']
spec=importlib.util.spec_from_file_location('museum_subtitles',REPO/'tools/OfflineVideo/generate_museum_subtitles.py')
formatter=importlib.util.module_from_spec(spec)
spec.loader.exec_module(formatter)


def verify(data,cues,total):
    assert data[:5]==b'MSUB\x03'
    assert struct.unpack_from('<H',data,5)[0]==800 and data[7:10]==bytes((32,2,len(cues)))
    assert struct.unpack_from('<H',data,10)[0]==6400 and data[12]==13
    assert struct.unpack_from('<I',data,16)[0]==total
    assert len(data)==512+6656*len(cues)
    for i,(start,end,text) in enumerate(cues):
        record=data[512+i*6656:512+(i+1)*6656]
        width,bitmap=formatter.render_bitmap(text)
        assert struct.unpack_from('<IIH',record)==(start,end,width)
        assert record[16:6416]==bitmap and any(bitmap)
        assert not any(record[6416:])


def main():
    output=ROOT/'packages/subtitles';output.mkdir(parents=True,exist_ok=True)
    rows=[]
    for i in range(6):
        srt=MEDIA/'字幕'/f'{NAMES[i]}.srt'
        wav=MEDIA/'音频'/f'{NAMES[i]}.wav'
        with wave.open(str(wav),'rb') as f:
            total=round(f.getnframes()*48000/f.getframerate())
        cues=formatter.parse_srt(srt,total,'direct')
        header=bytearray(512);header[:5]=b'MSUB\x03'
        struct.pack_into('<HBBBHB',header,5,800,32,2,len(cues),6400,13)
        struct.pack_into('<IIIII',header,16,total,*[total*n//5 for n in range(1,5)])
        data=bytearray(header)
        for start,end,text in cues:
            width,bitmap=formatter.render_bitmap(text)
            record=bytearray(6656);struct.pack_into('<IIHB',record,0,start,end,width,1)
            record[16:6416]=bitmap;data.extend(record)
        verify(data,cues,total)
        target=output/f'SUB{i}.BIN';target.write_bytes(data)
        verify(target.read_bytes(),cues,total)
        rows.append(dict(file=target.name,bytes=len(data),cues=len(cues),total_samples=total,
            timebase=48000,timing='direct',sha256=hashlib.sha256(data).hexdigest(),
            source_srt=str(srt.relative_to(REPO)),source_srt_sha256=hashlib.sha256(srt.read_bytes()).hexdigest()))
    (output/'manifest.json').write_text(json.dumps(dict(format='MSUB v3',tf_updated=False,tracks=rows),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS six MSUB tracks: exact cue times, decoded headers and bitmap payload readback; TF not accessed')


if __name__=='__main__':main()
