from pathlib import Path
import shutil

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[2] / "素材"
DEST = Path("E:/")
BACKUP = DEST / "BACKUP_MAIN2_20260920"
SIZE = (1920, 1080)


def render(source: Path, target: Path) -> None:
    with Image.open(source) as opened:
        image = opened.convert("RGB")
    scale = max(SIZE[0] / image.width, SIZE[1] / image.height)
    background = image.resize(
        (round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS
    )
    left = (background.width - SIZE[0]) // 2
    top = (background.height - SIZE[1]) // 2
    background = background.crop((left, top, left + SIZE[0], top + SIZE[1]))
    background = ImageEnhance.Brightness(
        background.filter(ImageFilter.GaussianBlur(36))
    ).enhance(0.45)

    foreground = image.resize((1080, 1080), Image.Resampling.LANCZOS)
    mask = Image.new("L", foreground.size, 255)
    for x in range(32):
        alpha = round(255 * x / 31)
        for y in range(1080):
            mask.putpixel((x, y), alpha)
            mask.putpixel((1079 - x, y), alpha)
    background.paste(foreground, (420, 0), mask)
    background.save(target, "BMP")


def main() -> None:
    artifacts = sorted(path for path in ROOT.iterdir() if path.is_dir())
    outputs = []
    for index, folder in enumerate(artifacts):
        outputs.append((folder / "全貌图.jpg", DEST / f"IMAGE{index}.BMP"))
        for detail, source in enumerate(sorted(folder.glob("细节*.jpg")), 1):
            outputs.append((source, DEST / f"ART{index}D{detail}.BMP"))
    assert len(outputs) == 20 and all(source.exists() for source, _ in outputs)

    BACKUP.mkdir(exist_ok=True)
    for _, target in outputs:
        backup = BACKUP / target.name
        if target.exists() and not backup.exists():
            shutil.copy2(target, backup)
    for source, target in outputs:
        render(source, target)
        with Image.open(target) as check:
            assert check.size == SIZE and check.mode == "RGB"
    print(f"prepared {len(outputs)} images; backup: {BACKUP}")


if __name__ == "__main__":
    main()
