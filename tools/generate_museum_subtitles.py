from pathlib import Path
import argparse
import html
import re
import struct
import wave

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2] / "素材"
FONT = Path(r"C:\Windows\Fonts\msyh.ttc")
WIDTH = 800
HEIGHT = 32
BITMAP_BYTES = WIDTH * HEIGHT // 8
RECORD_BYTES = 13 * 512
PAYLOAD_OFFSET = 16


def timestamp_ms(value: str) -> int:
    match = re.fullmatch(r"(\d+):(\d{2}):(\d{2})[,.](\d{1,3})", value.strip())
    if not match:
        raise ValueError(f"invalid SRT timestamp: {value}")
    hour, minute, second, milli = match.groups()
    if int(minute) >= 60 or int(second) >= 60:
        raise ValueError(f"invalid SRT timestamp: {value}")
    return ((int(hour) * 60 + int(minute)) * 60 + int(second)) * 1000 + int(milli.ljust(3, "0"))


def read_srt_text(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe\x00\x00", b"\x00\x00\xfe\xff")):
        return data.decode("utf-32")
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16")
    if b"\x00" in data:
        encoding = "utf-16-le" if data[1::2].count(0) > data[::2].count(0) else "utf-16-be"
        return data.decode(encoding)
    for encoding in ("utf-8-sig", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise ValueError(f"{path}: cannot decode SRT; save as UTF-8 or UTF-16")


def script_timestamp_ms(value: str) -> int:
    minute, second = value.split(":")
    return (int(minute) * 60 + int(second)) * 1000


def parse_scene_script(path: Path, total_frames: int):
    rows = []
    pattern = re.compile(
        r"^\|\s*(\d+)\s*\|\s*`([0-9:]+)\s*[–-]\s*([0-9:]+)`\s*\|\s*\*\*([^*]+)\*\*"
    )
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            rows.append((script_timestamp_ms(match.group(2)),
                         script_timestamp_ms(match.group(3)), match.group(4)))
    if len(rows) != 5 or rows[0][0] != 0:
        raise ValueError(f"{path}: expected five scene rows beginning at 00:00")
    script_end_ms = rows[-1][1]
    cuts = [round(start * total_frames / script_end_ms) for start, _, _ in rows[1:]]
    if not (0 < cuts[0] < cuts[1] < cuts[2] < cuts[3] < total_frames):
        raise ValueError(f"{path}: scene cuts must be ordered inside the WAV")
    return cuts


def timestamp_frames(value: str, total_frames: int, srt_end_ms: int,
                     timing_mode: str) -> int:
    ms = timestamp_ms(value)
    if timing_mode == "direct":
        return ms * 48
    return round(ms * total_frames / srt_end_ms)


def parse_srt(path: Path, total_frames: int, timing_mode: str, check_timing: bool = True):
    blocks = re.split(r"\n(?:[ \t]*\n)+", read_srt_text(path).replace("\r\n", "\n").replace("\r", "\n").strip())
    raw = []
    timing = re.compile(r"(\d+:\d{2}:\d{2}[,.]\d{1,3})\s*-->\s*(\d+:\d{2}:\d{2}[,.]\d{1,3})(?:\s+.*)?")
    for index, block in enumerate(blocks, 1):
        lines = block.splitlines()
        time_line = 1 if lines and lines[0].strip().isdigit() else 0
        match = timing.fullmatch(lines[time_line].strip()) if len(lines) > time_line else None
        if not match or len(lines) <= time_line + 1:
            raise ValueError(f"{path}: invalid SRT block {index}")
        text = "".join(lines[time_line + 1:]).strip()
        text = html.unescape(re.sub(r"</?(?:b|i|u|font)(?:\s[^>]*)?>", "", text, flags=re.IGNORECASE))
        if not text:
            raise ValueError(f"{path}: empty subtitle in block {index}")
        raw.append((*match.groups(), text))
    if not raw or len(raw) > 32:
        raise ValueError(f"{path}: cue count must be 1..32")
    if not check_timing:
        return [(timestamp_ms(start) * 48, timestamp_ms(end) * 48, text)
                for start, end, text in raw]
    srt_end_ms = timestamp_ms(raw[-1][1])
    if timing_mode == "auto":
        timing_mode = "direct" if srt_end_ms * 48 <= total_frames else "fit"
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
        text_height = box[3] - box[1]
        if (text_width <= WIDTH - 2 and text_height <= HEIGHT - 2) or font_size == 16:
            break
        font_size -= 1
    if text_width > WIDTH - 2 or text_height > HEIGHT - 2:
        raise ValueError(f"subtitle does not fit even at 16px: {text}")
    rendered_width = max(1, text_width + 2)
    image = Image.new("L", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(image)
    draw.text((1 - box[0], (HEIGHT - text_height) // 2 - box[1]),
              text, font=font, fill=255)
    outline = image.filter(ImageFilter.MaxFilter(3))
    body_payload = bytearray()
    outline_payload = bytearray()
    for y in range(HEIGHT):
        for byte_x in range(WIDTH // 8):
            body_value = 0
            outline_value = 0
            for bit in range(8):
                pixel_x = byte_x * 8 + bit
                if image.getpixel((pixel_x, y)) >= 96:
                    body_value |= 1 << (7 - bit)
                elif outline.getpixel((pixel_x, y)) >= 96:
                    outline_value |= 1 << (7 - bit)
            body_payload.append(body_value)
            outline_payload.append(outline_value)
    return rendered_width, bytes(body_payload + outline_payload)


def build_track(track: int, folder: Path, audio_dir: Path, destination: Path,
                timing_mode: str, subtitle_path: Path = None, scene_cuts=None):
    audio = audio_dir / f"AUDIO{track}.WAV"
    with wave.open(str(audio), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (2, 2, 48_000):
            raise ValueError(f"{audio}: expected PCM16 stereo 48kHz")
        total_frames = wav.getnframes()
    cues = parse_srt(subtitle_path or folder / "字幕.srt", total_frames, timing_mode)
    script = folder / "图片切换脚本.md"
    # ponytail: equal-duration fallback, not semantic audio/image alignment; optional script supplies precise cuts.
    if scene_cuts is None:
        scene_cuts = parse_scene_script(script, total_frames) if script.is_file() else [total_frames * n // 5 for n in range(1, 5)]
    if len(scene_cuts) != 4 or not (0 < scene_cuts[0] < scene_cuts[1] < scene_cuts[2] < scene_cuts[3] < total_frames):
        raise ValueError(f"{audio}: four scene cuts must be ordered inside the audio")

    header = bytearray(512)
    header[0:4] = b"MSUB"
    header[4] = 3
    struct.pack_into("<H", header, 5, WIDTH)
    header[7] = HEIGHT
    header[8] = 2
    header[9] = len(cues)
    struct.pack_into("<H", header, 10, BITMAP_BYTES * 2)
    header[12] = RECORD_BYTES // 512
    struct.pack_into("<I", header, 16, total_frames)
    struct.pack_into("<IIII", header, 20, *scene_cuts)

    output = bytearray(header)
    for start, end, text in cues:
        rendered_width, bitmap = render_bitmap(text)
        record = bytearray(RECORD_BYTES)
        struct.pack_into("<IIH", record, 0, start, end, rendered_width)
        record[10] = 1  # slide in from the right
        record[PAYLOAD_OFFSET:PAYLOAD_OFFSET + BITMAP_BYTES * 2] = bitmap
        output.extend(record)

    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"SUB{track}.BIN"
    target.write_bytes(output)
    if target.stat().st_size != 512 + len(cues) * RECORD_BYTES:
        raise RuntimeError(f"failed to verify {target}")
    return target, scene_cuts


def main() -> None:
    parser = argparse.ArgumentParser(description="Build FPGA TF subtitle packages from five SRT files")
    parser.add_argument("--dest", type=Path, default=Path("E:/"))
    parser.add_argument("--audio-dir", type=Path)
    parser.add_argument(
        "--timing-mode", choices=("direct", "fit", "auto"), default="direct",
        help="direct preserves SRT timestamps; fit scales to WAV; auto uses direct when it fits",
    )
    args = parser.parse_args()
    audio_dir = args.audio_dir or args.dest
    folders = sorted(path for path in ROOT.iterdir() if path.is_dir())
    if len(folders) != 5:
        raise ValueError(f"expected five artifact folders, found {len(folders)}")
    results = [
        build_track(track, folder, audio_dir, args.dest, args.timing_mode)
        for track, folder in enumerate(folders)
    ]
    print(f"timing={args.timing_mode}; generated " + ", ".join(
        f"{path.name}={path.stat().st_size}, cuts={cuts}"
        for path, cuts in results
    ))


if __name__ == "__main__":
    main()
