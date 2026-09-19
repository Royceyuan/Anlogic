#!/usr/bin/env python3
"""Play one museum SRT over the existing FPGA UART subtitle protocol."""
import argparse
import time
import wave
from pathlib import Path

from send_subtitle import HEIGHT, WIDTH, packet, rasterize


ARTIFACT_DIRS = (
    "01_越王勾践剑", "02_四羊方尊", "03_金缕玉衣", "04_马踏飞燕", "05_长信宫灯",
)


def timestamp(value: str) -> float:
    hours, minutes, rest = value.replace(",", ".").split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(rest)


def read_srt(path: Path):
    cues = []
    for block in path.read_text(encoding="utf-8-sig").replace("\r", "").strip().split("\n\n"):
        lines = block.splitlines()
        start, end = (timestamp(item.strip()) for item in lines[1].split("-->"))
        cues.append((start, end, "".join(lines[2:])))
    return cues


def wav_duration(path: Path) -> float:
    with wave.open(str(path), "rb") as source:
        return source.getnframes() / source.getframerate()


def send(port, payload: bytes):
    port.reset_input_buffer()
    port.write(payload)
    port.flush()
    reply = port.read_until(b"\n").decode("ascii", "replace").strip()
    if reply != "OK":
        raise RuntimeError(f"FPGA reply: {reply or 'none'}")


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=int, choices=range(5), required=True)
    parser.add_argument("--port", help="CH340 port, for example COM5")
    parser.add_argument("--font", default=r"C:\Windows\Fonts\msyhbd.ttc")
    parser.add_argument("--size", type=int, default=28)
    parser.add_argument("--subtitle-root", type=Path, default=root / "素材")
    parser.add_argument("--media-root", type=Path, default=Path("E:/"))
    parser.add_argument("--audio-seconds", type=float,
                        help="override WAV duration (useful for offline validation)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    srt = args.subtitle_root / ARTIFACT_DIRS[args.artifact] / "字幕.srt"
    wav = args.media_root / f"AUDIO{args.artifact}.WAV"
    cues = read_srt(srt)
    audio_seconds = args.audio_seconds or wav_duration(wav)
    scale = audio_seconds / cues[-1][1]
    payloads = [packet(rasterize(text, args.font, args.size, 2), False, 1, 2)
                for _start, _end, text in cues]
    clear = packet(bytes(WIDTH * HEIGHT // 4), False, 1, 2, clear=True)
    print(f"artifact={args.artifact}, cues={len(cues)}, audio={audio_seconds:.2f}s, scale={scale:.4f}")
    if args.dry_run:
        return 0
    if not args.port:
        parser.error("--port is required unless --dry-run is used")

    import serial
    with serial.Serial(args.port, 115200, timeout=2) as port:
        input("等待 FPGA 完成图片预载；听到讲解音频开始时按 Enter：")
        started = time.monotonic()
        for (cue_start, _cue_end, text), payload in zip(cues, payloads):
            time.sleep(max(0.0, started + cue_start * scale - time.monotonic()))
            send(port, payload)
            print(f"{cue_start * scale:6.2f}s  {text}")
        time.sleep(max(0.0, started + audio_seconds - time.monotonic()))
        send(port, clear)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
