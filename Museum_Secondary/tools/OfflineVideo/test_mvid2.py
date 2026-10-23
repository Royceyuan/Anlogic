"""Small real-file round trip: video bytes, PCM padding, caption index and rejection."""
from pathlib import Path
import struct
import tempfile
import wave
import zlib

from mvid2 import FRAME_BYTES,PCM_BYTES,PCM_STRIDE,build,parse_header,self_test,verify

self_test()
with tempfile.TemporaryDirectory(prefix='museum-mvid2-test-') as name:
    root=Path(name)
    raw=root/'input.BIN'
    a=b'\x12\x34'*(FRAME_BYTES//2)
    b=b'\xab\xcd'*(FRAME_BYTES//2)
    header=bytearray(512)
    struct.pack_into('<4s6H4IQ',header,0,b'MVID',1,512,640,480,30,1,2,FRAME_BYTES,1,0,2*FRAME_BYTES)
    struct.pack_into('<I',header,508,zlib.crc32(header[:508]))
    raw.write_bytes(header+a+b)
    srt=root/'input.srt'
    srt.write_text('1\n00:00:00,000 --> 00:00:00,060\n离线音视频同步\n',encoding='utf-8')
    audio=root/'input.wav'
    pcm=struct.pack('<2h',1234,-2345)*3200
    with wave.open(str(audio),'wb') as f:
        f.setparams((2,2,48000,3200,'NONE','not compressed'));f.writeframes(pcm)
    for use_audio in (False,True):
        dest=root/('sound.BIN' if use_audio else 'silent.BIN')
        build(raw,dest,audio=audio if use_audio else None,subtitle=srt,artifact=255 if use_audio else 0)
        info=verify(dest)
        assert info['subtitle_count']==1 and info['audio']==use_audio
        with dest.open('rb') as f:
            header=f.read(512)
            assert f.read(FRAME_BYTES)==a
            if use_audio:
                assert f.read(PCM_BYTES)==pcm[:PCM_BYTES]
                assert f.read(PCM_STRIDE-PCM_BYTES)==bytes(PCM_STRIDE-PCM_BYTES)
            assert f.read(FRAME_BYTES)==b
        bad=bytearray(header);struct.pack_into('<I',bad,40,1)
        struct.pack_into('<I',bad,508,zlib.crc32(bad[:508]))
        try:parse_header(bad,dest.stat().st_size)
        except ValueError:pass
        else:raise AssertionError('CRC-valid invalid stride accepted')
        try:build(raw,dest,subtitle=srt)
        except FileExistsError:pass
        else:raise AssertionError('Existing package overwritten')
print('PASS actual two-frame video/PCM/caption round trip and invalid-stride/overwrite rejection')
