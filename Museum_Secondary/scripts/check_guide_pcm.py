"""Compare the local GUIDE package's interleaved PCM with its source WAV."""
import hashlib
import json
from pathlib import Path
import struct
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]


def main():
    package=ROOT/'tools/OfflineVideo/packages/promo_final_release/GUIDE.BIN'
    folder=ROOT/'_build_secondary/av_diagnostics';folder.mkdir(parents=True,exist_ok=True)
    pcm=bytearray()
    with package.open('rb') as stream:
        header=stream.read(512)
        frames=struct.unpack_from('<I',header,16)[0]
        record=struct.unpack_from('<I',header,40)[0]
        for frame in range(frames):
            stream.seek(512+frame*record+640*480*2)
            pcm.extend(stream.read(6400))
    with wave.open(str(ROOT/'assets/音频/06_总览宣传片.wav'),'rb') as source:
        source_pcm=source.readframes(source.getnframes())
    output=folder/'guide_package_pcm.wav'
    with wave.open(str(output),'wb') as wav:
        wav.setparams((2,2,48000,len(pcm)//4,'NONE','not compressed'));wav.writeframes(pcm)
    samples=np.frombuffer(pcm,dtype='<i2').reshape(-1,2).astype(np.int32)
    report=dict(source_pcm_exact=pcm==source_pcm,samples=len(samples),peak=int(np.abs(samples).max()),
        clipped_samples=int(np.count_nonzero(np.abs(samples)>=32767)),
        pcm_sha256=hashlib.sha256(pcm).hexdigest(),output=str(output))
    (folder/'guide_pcm_check.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
