"""Convert a movie to the offline FPGA MVID v1 stream (640x360, 30 fps).

VIDEO0.BIN is a 512-byte little-endian header followed by top-down, packed
RGB565 big-endian frames. Each 460800-byte frame occupies exactly 900 sectors.
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

WIDTH, HEIGHT, FPS = 640, 360, 30
FRAME_BYTES = WIDTH * HEIGHT * 2


def make_header(frames):
    header = bytearray(512)
    struct.pack_into('<4s6H4IQ', header, 0, b'MVID', 1, 512, WIDTH, HEIGHT,
                     FPS, 1, frames, FRAME_BYTES, 1, 0, frames * FRAME_BYTES)
    struct.pack_into('<I', header, 508, zlib.crc32(header[:508]))
    return header


def parse_header(header, file_bytes):
    if len(header) != 512 or header[:4] != b'MVID':
        raise ValueError('Not a complete MVID header')
    if zlib.crc32(header[:508]) != struct.unpack_from('<I', header, 508)[0]:
        raise ValueError('Header CRC32 mismatch')
    fields = struct.unpack_from('<4s6H4IQ', header)
    _, version, header_bytes, width, height, fps_num, fps_den, frames, frame_bytes, pixel_format, flags, payload_bytes = fields
    if (version, header_bytes, width, height, fps_num, fps_den, frame_bytes, pixel_format, flags) != (
            1, 512, WIDTH, HEIGHT, FPS, 1, FRAME_BYTES, 1, 0):
        raise ValueError('Unsupported MVID format')
    if frames < 1 or payload_bytes != frames * FRAME_BYTES or file_bytes != 512 + payload_bytes:
        raise ValueError('Frame count/length mismatch or truncated movie')
    return dict(format='MVID v1', width=width, height=height, fps=FPS, frames=frames,
                frame_bytes=frame_bytes, payload_bytes=payload_bytes,
                duration_seconds=frames / FPS, pixel_format='RGB565 big-endian', audio=False)


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
    report = parse_header(make_header(2), 512 + 2 * FRAME_BYTES)
    assert report['frames'] == 2 and FRAME_BYTES // 512 == 900
    bad = make_header(2)
    bad[8] ^= 1
    for header, length in ((bad, 512 + 2 * FRAME_BYTES), (make_header(2), 512 + FRAME_BYTES)):
        try:
            parse_header(header, length)
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid movie accepted')
    print('PASS MVID header, frame-sector alignment, CRC and truncation checks')


def convert(source, output, ffmpeg):
    source = source.resolve(strict=True)
    output = output.resolve()
    if output.exists():
        raise FileExistsError(f'Existing output is preserved: {output}')
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_name(output.name + '.part')
    log = output.with_name(output.name + '.ffmpeg.log')
    if partial.exists() or log.exists():
        raise FileExistsError('A previous partial conversion exists; inspect it before retrying')
    command = [str(ffmpeg), '-hide_banner', '-loglevel', 'error', '-nostdin', '-i', str(source),
               '-map', '0:v:0', '-an', '-vf',
               'fps=30,scale=640:360:force_original_aspect_ratio=decrease:flags=lanczos,'
               'pad=640:360:(ow-iw)/2:(oh-ih)/2,setsar=1',
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
        frames, remainder = divmod(payload_bytes, FRAME_BYTES)
        if remainder or frames == 0:
            raise ValueError('FFmpeg returned an incomplete frame')
        header = make_header(frames)
        parse_header(header, 512 + payload_bytes)
        stream.seek(0)
        stream.write(header)
    report = verify(partial)
    partial.rename(output)
    log.unlink()
    report['input'] = str(source)
    report['input_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    report['output'] = str(output)
    report['board_playback_verified'] = False
    output.with_suffix('.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
    parser.add_argument('--check', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif args.check:
        print(json.dumps(verify(args.check), ensure_ascii=False, indent=2))
    elif args.input and args.output and args.ffmpeg:
        convert(args.input, args.output, args.ffmpeg)
    else:
        parser.error('Supply --input, --output and --ffmpeg, or --check / --self-test')
