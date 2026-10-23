"""Small end-to-end conversion check; writes only into a new local test folder."""
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import wave
import offline_museum_packager as packager


def main():
    parent=packager.REPO/'_build_offline_media_tool'
    parent.mkdir(exist_ok=True)
    folder=Path(tempfile.mkdtemp(prefix='conversion_test_',dir=parent))
    film=folder/'source.mp4';srt=folder/'source.srt'
    subprocess.run([str(packager.FF),'-v','error','-nostdin','-f','lavfi','-i',
        'testsrc2=size=1280x720:rate=30','-f','lavfi','-i','sine=frequency=440:sample_rate=48000',
        '-t','0.2','-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac',str(film)],check=True)
    srt.write_text('1\n00:00:00,000 --> 00:00:00,150\n离线字幕自检\n',encoding='utf-8')
    artifact_srt=folder/'artifact.srt'
    artifact_srt.write_text('1\n00:00:01,000 --> 00:00:01,150\n晚于视频结束的主板字幕\n',encoding='utf-8')
    manifest=packager.build([film]*7,[artifact_srt]*5+[srt],folder,print)
    rows=json.loads(manifest.read_text(encoding='utf-8'))['files']
    assert len(rows)==13 and len({r['file'] for r in rows})==13
    for row in rows:
        path=Path(row['path'])
        assert packager.mvid2.sha256(path)==row['sha256']
        if path.name.startswith('SUB'):
            data=path.read_bytes()
            assert data[:5]==b'MSUB\x03' and len(data)==7168
            assert struct.unpack_from('<II',data,512)==((0,7200) if path.name=='SUB5.BIN' else (48000,55200))
        else:
            result=packager.mvid2.verify(path)
            assert (result['width'],result['height'],result['fps'],result['frames'])==(640,480,30,6)
            assert result['audio']==(path.name=='GUIDE.BIN')
            assert result['subtitle_count']==(1 if path.name=='GUIDE.BIN' else 0)
    for i in range(5):
        with wave.open(str(packager.MEDIA/'音频'/f'{packager.NAMES[i]}.wav'),'rb') as track:
            total=round(track.getnframes()*48000/track.getframerate())
        assert struct.unpack_from('<I',(Path(rows[0]['path']).parent/f'SUB{i}.BIN').read_bytes(),16)[0]==total
    invalid=folder/'invalid_guide_manifest.json'
    invalid.write_text(json.dumps(dict(format='museum offline AV install set',files=[
        dict(file='ART0.BIN'),dict(file='SUB5.BIN')])),encoding='utf-8')
    for flags,expected in (([],'Unexpected media set size or format'),
            (['-GuideOnly'],'Missing or duplicate target name'),
            (['-ArtifactsOnly'],'Unexpected media set size or format'),
            (['-ArtifactIndex','0'],'Unexpected media set size or format'),
            (['-ArtifactIndex','0','-GuideOnly'],'Choose only one partial update mode'),
            (['-GuideOnly','-ArtifactsOnly'],'Choose only one partial update mode')):
        result=subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',
            str(packager.REPO/'scripts/install_offline_av.ps1'),'-Manifest',str(invalid),*flags],
            capture_output=True,text=True,errors='replace')
        assert result.returncode!=0 and expected in result.stdout+result.stderr
    invalid.write_text(json.dumps(dict(format='museum offline AV install set',files=[
        dict(file='ART1.BIN')])),encoding='utf-8')
    result=subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',
        str(packager.REPO/'scripts/install_offline_av.ps1'),'-Manifest',str(invalid),
        '-ArtifactIndex','0'],capture_output=True,text=True,errors='replace')
    assert result.returncode!=0 and 'Missing or duplicate target name' in result.stdout+result.stderr
    print(f'PASS real FFmpeg conversion: seven movies, GUIDE PCM, independent main-timeline captions beyond movie duration; invalid/mutually-exclusive update sets rejected before card access; {manifest}')


if __name__=='__main__':main()
