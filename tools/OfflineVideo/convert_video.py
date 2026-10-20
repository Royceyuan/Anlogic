"""Convert a movie to the offline FPGA MVID v1 stream (640x360 or 640x480).

VIDEO0.BIN is a 512-byte little-endian header followed by top-down, packed
RGB565 big-endian frames. Frames occupy exactly 900 or 1200 sectors.
The FPGA reads raw pixels; the PC performs conversion before the TF is installed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import zlib

WIDTH, HEIGHT = 640, 360
FRAME_BYTES = WIDTH * HEIGHT * 2


def make_header(frames, fps=30, height=360):
    if (height, fps) not in ((360, 30), (360, 40), (480, 30)):
        raise ValueError('Supported formats: 360p30, archived 360p40, 480p30')
    frame_bytes = WIDTH * height * 2
    header = bytearray(512)
    struct.pack_into('<4s6H4IQ', header, 0, b'MVID', 1, 512, WIDTH, height,
                     fps, 1, frames, frame_bytes, 1, 0, frames * frame_bytes)
    struct.pack_into('<I', header, 508, zlib.crc32(header[:508]))
    return header


def parse_header(header, file_bytes, expected_fps=None, expected_height=None):
    if len(header) != 512 or header[:4] != b'MVID':
        raise ValueError('Not a complete MVID header')
    if zlib.crc32(header[:508]) != struct.unpack_from('<I', header, 508)[0]:
        raise ValueError('Header CRC32 mismatch')
    fields = struct.unpack_from('<4s6H4IQ', header)
    _, version, header_bytes, width, height, fps_num, fps_den, frames, frame_bytes, pixel_format, flags, payload_bytes = fields
    if (height, fps_num) not in ((360, 30), (360, 40), (480, 30)) or (
            version, header_bytes, width, fps_den, frame_bytes, pixel_format, flags) != (
            1, 512, WIDTH, 1, WIDTH * height * 2, 1, 0) or any(header[40:508]):
        raise ValueError('Unsupported MVID format')
    if expected_fps is not None and fps_num != expected_fps:
        raise ValueError('Movie frame rate does not match the selected FPGA build')
    if expected_height is not None and height != expected_height:
        raise ValueError('Movie height does not match the selected FPGA build')
    if frames < 1 or payload_bytes != frames * frame_bytes or file_bytes != 512 + payload_bytes or file_bytes >= 2**32:
        raise ValueError('Frame count/length mismatch or truncated movie')
    return dict(format='MVID v1', width=width, height=height, fps=fps_num, frames=frames,
                frame_bytes=frame_bytes, payload_bytes=payload_bytes,
                duration_seconds=frames / fps_num, pixel_format='RGB565 big-endian', audio=False)


def verify(path):
    with path.open('rb') as stream:
        header = stream.read(512)
        report = parse_header(header, path.stat().st_size)
        digest = hashlib.sha256(header)
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    report['sha256'] = digest.hexdigest()
    report['file_bytes'] = path.stat().st_size
    return report


def self_test():
    for fps in (30, 40):
        report = parse_header(make_header(2, fps), 512 + 2 * FRAME_BYTES, fps)
        assert report['fps'] == fps and report['duration_seconds'] == 2 / fps
        try:
            parse_header(make_header(2, fps), 512 + 2 * FRAME_BYTES, 70 - fps)
        except ValueError:
            pass
        else:
            raise AssertionError('Wrong build frame rate accepted')
    report = parse_header(make_header(2), 512 + 2 * FRAME_BYTES)
    assert report['frames'] == 2 and FRAME_BYTES // 512 == 900
    bad = make_header(2)
    bad[8] ^= 1
    unsupported = make_header(2)
    struct.pack_into('<H', unsupported, 12, 50)
    struct.pack_into('<I', unsupported, 508, zlib.crc32(unsupported[:508]))
    for header, length in ((bad, 512 + 2 * FRAME_BYTES), (make_header(2), 512 + FRAME_BYTES),
                           (unsupported, 512 + 2 * FRAME_BYTES)):
        try:
            parse_header(header, length)
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid movie accepted')
    header480 = make_header(2, 30, 480)
    report480 = parse_header(header480, 512 + 2 * 640 * 480 * 2, 30, 480)
    assert report480['frame_bytes'] == 614400 and report480['frame_bytes'] // 512 == 1200
    try:
        parse_header(header480, 512 + 2 * 640 * 480 * 2, 30, 360)
    except ValueError:
        pass
    else:
        raise AssertionError('Wrong build height accepted')
    print('PASS 360p30/40 and 480p30 headers, build rate/height mismatch, sector alignment, CRC and truncation checks')


def convert(source, output, ffmpeg, fps=30, height=360):
    source = source.resolve(strict=True)
    output = output.resolve()
    if output.exists():
        raise FileExistsError(f'Existing output is preserved: {output}')
    make_header(1, fps, height)
    frame_bytes = WIDTH * height * 2
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_name(output.name + '.part')
    log = output.with_name(output.name + '.ffmpeg.log')
    if partial.exists() or log.exists():
        raise FileExistsError('A previous partial conversion exists; inspect it before retrying')
    # 480p uses anamorphic samples: preserve the full 16:9 field, then sample
    # it into 640x480. FPGA's 2x / 3:2 scaling restores geometry at 1280x720.
    vf = (f'fps={fps},scale=1280:720:force_original_aspect_ratio=decrease:flags=lanczos,'
          'pad=1280:720:(ow-iw)/2:(oh-ih)/2,scale=640:480:flags=lanczos,setsar=4/3'
          if height == 480 else
          f'fps={fps},scale=640:360:force_original_aspect_ratio=decrease:flags=lanczos,'
          'pad=640:360:(ow-iw)/2:(oh-ih)/2,setsar=1')
    command = [str(ffmpeg), '-hide_banner', '-loglevel', 'error', '-nostdin', '-i', str(source),
               '-map', '0:v:0', '-an', '-vf',
               vf,
               '-pix_fmt', 'rgb565be', '-c:v', 'rawvideo', '-f', 'rawvideo', 'pipe:1']
    with partial.open('xb') as stream, log.open('xb') as errors:
        stream.write(bytes(512))
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors) as process:
            for chunk in iter(lambda: process.stdout.read(1024 * 1024), b''):
                stream.write(chunk)
            result = process.wait()
        if result:
            raise RuntimeError(f'FFmpeg failed; inspect {log}')
        payload_bytes = stream.tell() - 512
        frames, remainder = divmod(payload_bytes, frame_bytes)
        if remainder or frames == 0:
            raise ValueError('FFmpeg returned an incomplete frame')
        header = make_header(frames, fps, height)
        parse_header(header, 512 + payload_bytes, fps, height)
        stream.seek(0)
        stream.write(header)
    report = verify(partial)
    partial.rename(output)
    log.unlink()
    report['input'] = str(source)
    report['input_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    report['output'] = str(output)
    report['board_playback_verified'] = False
    report['display_aspect_ratio'] = '16:9'
    report['sample_aspect_ratio'] = '4:3' if height == 480 else '1:1'
    report['ffmpeg_filter'] = vf
    output.with_suffix('.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
    parser.add_argument('--fps', type=int, choices=(30, 40), default=30,
                        help='Must match FPGA build; default: 30')
    parser.add_argument('--height', type=int, choices=(360, 480), default=360,
                        help='Must match FPGA build; 480 uses anamorphic 16:9 display samples')
    parser.add_argument('--check', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif args.check:
        print(json.dumps(verify(args.check), ensure_ascii=False, indent=2))
    elif args.input and args.output and args.ffmpeg:
        convert(args.input, args.output, args.ffmpeg, args.fps, args.height)
    else:
        parser.error('Supply --input, --output and --ffmpeg, or --check / --self-test')
