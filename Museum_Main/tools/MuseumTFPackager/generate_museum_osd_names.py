"""Pack the five artifact folder names into the MAIN-3 TF bitmap file."""

from argparse import ArgumentParser
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2] / "素材"
FONT = Path(r"C:\Windows\Fonts\msyh.ttc")
WIDTH, HEIGHT = 160, 16


def pack_name(name: str, font: ImageFont.FreeTypeFont) -> bytes:
    bounds = font.getbbox(name)
    width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
    if width > WIDTH or height > HEIGHT:
        raise ValueError(f"文物名称超过 {WIDTH}x{HEIGHT}：{name}")
    image = Image.new("1", (WIDTH, HEIGHT))
    ImageDraw.Draw(image).text(
        (-bounds[0], (HEIGHT - height) // 2 - bounds[1]),
        name, font=font, fill=1,
    )
    payload = bytes(
        sum(image.getpixel((x + bit, y)) << (7 - bit) for bit in range(8))
        for y in range(HEIGHT)
        for x in range(0, WIDTH, 8)
    )
    return payload + bytes(512 - len(payload))


def make_package(root: Path, font_path: Path) -> bytes:
    folders = sorted(path for path in root.iterdir() if path.is_dir())
    if len(folders) != 5:
        raise ValueError(f"应有 5 个文物目录，实际 {len(folders)} 个")
    font = ImageFont.truetype(str(font_path), 16)
    header = bytearray(512)
    header[:12] = b"ONAM" + bytes([1, 5, 160, 0, 16, 1, 0, 12])
    bitmaps = []
    for index, folder in enumerate(folders, 1):
        prefix, separator, name = folder.name.partition("_")
        if not separator or prefix != f"{index:02d}" or not name:
            raise ValueError(f"目录名称需要 NN_文物名：{folder.name}")
        bitmaps.append(pack_name(name, font))
    return bytes(header) + b"".join(bitmaps)


def main() -> None:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--font", type=Path, default=FONT)
    parser.add_argument("--dest", type=Path, default=Path("release/media/OSDNAME.BIN"))
    args = parser.parse_args()
    package = make_package(args.root, args.font)
    args.dest.parent.mkdir(parents=True, exist_ok=True)
    args.dest.write_bytes(package)
    print(f"{args.dest}: {len(package)} bytes")


if __name__ == "__main__":
    main()
