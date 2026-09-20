from pathlib import Path
import argparse
import re
import struct
import wave

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2] / "素材"
FONT = Path(r"C:\Windows\Fonts\msyh.ttc")
WIDTH = 800
HEIGHT = 32
BITMAP_BYTES = WIDTH * HEIGHT // 8
RECORD_BYTES = 7 * 512
PAYLOAD_OFFSET = 16


def timestamp_ms(value: str) -> int:
    hour, minute, rest = value.split(":")
    second, milli = rest.split(",")
    return ((int(hour) * 60 + int(minute)) * 60 + int(second)) * 1000 + int(milli)


def timestamp_frames(value: str, total_frames: int, srt_end_ms: int,
                     timing_mode: str) -> int:
    ms = timestamp_ms(value)
    if timing_mode == "direct":
        return ms * 48
    return round(ms * total_frames / srt_end_ms)


def parse_srt(path: Path, total_frames: int, timing_mode: str):
    blocks = re.split(r"\r?\n\r?\n", path.read_text(encoding="utf-8").strip())
    raw = []
    for block in blocks:
        lines = block.splitlines()
        if len(lines) < 3:
            continue
        start, end = lines[1].split(" --> ")
        raw.append((start, end, "".join(lines[2:]).strip()))
    if not raw or len(raw) > 32:
        raise ValueError(f"{path}: cue count must be 1..32")
    srt_end_ms = timestamp_ms(raw[-1][1])
    cues = [
        (timestamp_frames(start, total_frames, srt_end_ms, timing_mode),
         timestamp_frames(end, total_frames, srt_end_ms, timing_mode), text)
        for start, end, text in raw
    ]
    previous_end = 0
    for start, end, _ in cues:
        if start < previous_end or end <= start:
            raise ValueError(f"{path}: cue times must be ordered and non-overlapping")
        previous_end = end
    if timing_mode == "direct" and cues[-1][1] > total_frames:
        raise ValueError(
            f"{path}: SRT ends at {cues[-1][1] / 48_000:.3f}s, "
            f"after WAV duration {total_frames / 48_000:.3f}s; "
            "align the SRT to this WAV or explicitly use --timing-mode fit"
        )
    return cues


def render_bitmap(text: str):
    font_size = 28
    while True:
        font = ImageFont.truetype(str(FONT), font_size)
        box = font.getbbox(text)
        text_width = box[2] - box[0]
        if text_width <= WIDTH or font_size == 16:
            break
        font_size -= 1
    if text_width > WIDTH:
        raise ValueError(f"subtitle is too wide even at 16px: {text}")
    rendered_width = max(1, text_width)
    image = Image.new("L", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)
    text_height = box[3] - box[1]
    draw.text((-box[0], (HEIGHT - text_height) // 2 - box[1]), text, font=font, fill=255)
    payload = bytearray()
    for y in range(HEIGHT):
        for byte_x in range(WIDTH // 8):
            value = 0
            for bit in range(8):
                if image.getpixel((byte_x * 8 + bit, y)) >= 96:
                    value |= 1 << (7 - bit)
            payload.append(value)
    return rendered_width, bytes(payload)


def build_track(track: int, folder: Path, audio_dir: Path, destination: Path,
                timing_mode: str) -> Path:
    audio = audio_dir / f"AUDIO{track}.WAV"
    with wave.open(str(audio), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (2, 2, 48_000):
            raise ValueError(f"{audio}: expected PCM16 stereo 48kHz")
        total_frames = wav.getnframes()
    cues = parse_srt(folder / "字幕.srt", total_frames, timing_mode)

    header = bytearray(512)
    header[0:4] = b"MSUB"
    header[4] = 1
    struct.pack_into("<H", header, 5, WIDTH)
    header[7] = HEIGHT
    header[8] = 1
    header[9] = len(cues)
    struct.pack_into("<H", header, 10, BITMAP_BYTES)
    header[12] = RECORD_BYTES // 512
    struct.pack_into("<I", header, 16, total_frames)

    output = bytearray(header)
    for start, end, text in cues:
        rendered_width, bitmap = render_bitmap(text)
        record = bytearray(RECORD_BYTES)
        struct.pack_into("<IIH", record, 0, start, end, rendered_width)
        record[10] = 1  # slide in from the right
        record[PAYLOAD_OFFSET:PAYLOAD_OFFSET + BITMAP_BYTES] = bitmap
        output.extend(record)

    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"SUB{track}.BIN"
    target.write_bytes(output)
    if target.stat().st_size != 512 + len(cues) * RECORD_BYTES:
        raise RuntimeError(f"failed to verify {target}")
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description="Build FPGA TF subtitle packages from five SRT files")
    parser.add_argument("--dest", type=Path, default=Path("E:/"))
    parser.add_argument("--audio-dir", type=Path)
    parser.add_argument(
        "--timing-mode", choices=("direct", "fit"), default="direct",
        help="direct preserves SRT timestamps; fit scales the whole timeline to WAV duration",
    )
    args = parser.parse_args()
    audio_dir = args.audio_dir or args.dest
    folders = sorted(path for path in ROOT.iterdir() if path.is_dir())
    if len(folders) != 5:
        raise ValueError(f"expected five artifact folders, found {len(folders)}")
    outputs = [
        build_track(track, folder, audio_dir, args.dest, args.timing_mode)
        for track, folder in enumerate(folders)
    ]
    print(f"timing={args.timing_mode}; generated " +
          ", ".join(f"{path.name}={path.stat().st_size}" for path in outputs))


if __name__ == "__main__":
    main()
