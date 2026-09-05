#!/usr/bin/env python3
"""Rasterize one UTF-8 subtitle line and send a v66/v67 UART subtitle packet."""
import argparse
import struct
import sys

from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH, HEIGHT = 800, 32


def crc16_ccitt(data: bytes) -> int:
    crc = 0xFFFF
    for value in data:
        crc ^= value << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def rasterize(text: str, font_path: str, font_size: int, bits_per_pixel: int,
              thicken: bool = False, pixel_scale: int = 1, center: bool = True) -> bytes:
    logical_width = WIDTH // pixel_scale
    logical_height = HEIGHT // pixel_scale
    image = Image.new("L", (logical_width, logical_height), 0)
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(font_path, max(1, font_size // pixel_scale))
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    if right - left > logical_width:
        raise ValueError(f"text is {(right - left) * pixel_scale}px wide; maximum is {WIDTH}px")
    x = (logical_width - (right - left)) // 2 - left if center else 0
    y = (logical_height - (bottom - top)) // 2 - top
    draw.text((x, y), text, font=font, fill=255)
    if thicken:
        # The FPGA payload is intentionally 1-bit. A one-pixel dilation keeps
        # thin glyph strokes contiguous after monitor scaling and photography.
        image = image.filter(ImageFilter.MaxFilter(3))
    if pixel_scale != 1:
        image = image.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    out = bytearray()
    pixels_per_byte = 8 // bits_per_pixel
    for y in range(HEIGHT):
        for x in range(0, WIDTH, pixels_per_byte):
            value = 0
            for pixel in range(pixels_per_byte):
                shade = image.getpixel((x + pixel, y))
                if bits_per_pixel == 1:
                    level = int(shade >= 128)
                    value |= level << (7 - pixel)
                else:
                    level = (shade * 3 + 127) // 255
                    value |= level << (6 - pixel * 2)
            out.append(value)
    return bytes(out)


def level_bars(bits_per_pixel: int) -> bytes:
    """Return wide, constant-grey diagnostic bars for subtitle RAM readback."""
    out = bytearray()
    pixels_per_byte = 8 // bits_per_pixel
    for _y in range(HEIGHT):
        for x in range(0, WIDTH, pixels_per_byte):
            value = 0
            for pixel in range(pixels_per_byte):
                level = ((x + pixel) // 32) & ((1 << bits_per_pixel) - 1)
                if bits_per_pixel == 1:
                    value |= level << (7 - pixel)
                else:
                    value |= level << (6 - pixel * 2)
            out.append(value)
    return bytes(out)


def packet(bitmap: bytes, scroll: bool, speed: int, version: int, clear: bool = False) -> bytes:
    if len(bitmap) not in (WIDTH * HEIGHT // 8, WIDTH * HEIGHT // 4):
        raise ValueError("internal bitmap length error")
    mode = ((speed & 0x07) << 1) | int(scroll)
    if clear:
        mode |= 0x80
    header = bytes((version, mode)) + struct.pack("<HBH", WIDTH, HEIGHT, len(bitmap))
    body = header + bitmap
    return b"\x55\xAA" + body + struct.pack("<H", crc16_ccitt(body))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="CH340 COM port, e.g. COM5")
    parser.add_argument("--font", help="TTF/OTF font containing the Chinese glyphs")
    parser.add_argument("--text", help="UTF-8 subtitle text")
    parser.add_argument("--size", type=int, default=28, help="font size in pixels (default: 28)")
    parser.add_argument("--scroll", action="store_true", help="enable cyclic left scroll")
    parser.add_argument("--speed", type=int, choices=range(1, 8), default=3,
                        help="scroll pixels per video frame, 1..7 (default: 3)")
    parser.add_argument("--thicken", action="store_true",
                        help="dilate glyphs by one pixel for a heavier 1-bit stroke")
    parser.add_argument("--pixel-scale", type=int, choices=(1, 2), default=1,
                        help="render at half resolution then 2x-nearest scale; use 2 for thick stable strokes")
    parser.add_argument("--format", choices=("v66", "v67"), default="v67",
                        help="subtitle bitstream protocol; v67 is 2-bit anti-aliased (default)")
    parser.add_argument("--pattern", choices=("levels",),
                        help="send 32-pixel-wide grey bars instead of text for display diagnosis")
    parser.add_argument("--clear", action="store_true", help="hide the currently displayed subtitle")
    parser.add_argument("--dry-run", action="store_true", help="build and validate a packet without opening COM")
    args = parser.parse_args()
    try:
        bits_per_pixel = 1 if args.format == "v66" else 2
        version = 1 if args.format == "v66" else 2
        if args.clear:
            bitmap = bytes(WIDTH * HEIGHT * bits_per_pixel // 8)
        elif args.pattern == "levels":
            bitmap = level_bars(bits_per_pixel)
        else:
            if not args.text or not args.font:
                parser.error("--text and --font are required unless --pattern is used")
            bitmap = rasterize(args.text, args.font, args.size, bits_per_pixel,
                               args.thicken, args.pixel_scale, center=not args.scroll)
        payload = packet(bitmap, args.scroll, args.speed, version, args.clear)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    if args.dry_run:
        print(f"packet OK: {len(payload)} bytes, crc={payload[-2:].hex()}")
        return 0
    try:
        import serial
    except ModuleNotFoundError:
        print("pyserial is required: py -m pip install --user pyserial", file=sys.stderr)
        return 2
    with serial.Serial(args.port, 115200, timeout=2) as port:
        port.reset_input_buffer()
        port.write(payload)
        port.flush()
        reply = port.read_until(b"\n").decode("ascii", "replace").strip()
    print(reply or "no reply")
    return 0 if reply == "OK" else 1


if __name__ == "__main__":
    raise SystemExit(main())
