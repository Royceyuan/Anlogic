from pathlib import Path
import shutil

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2] / "素材"
DEST = Path("E:/")
BACKUP = DEST / "BACKUP_MAIN2_BEFORE_FULLSCREEN_20260920"
SIZE = (1920, 1080)
FOREGROUND_SIZE = 1080
SIDE_WIDTH = (SIZE[0] - FOREGROUND_SIZE) // 2
EDGE_SOURCE_WIDTH = 16


def render(source: Path, target: Path) -> None:
    with Image.open(source) as opened:
        image = opened.convert("RGB")
    foreground = image.resize(
        (FOREGROUND_SIZE, FOREGROUND_SIZE), Image.Resampling.LANCZOS
    )
    fullscreen = Image.new("RGB", SIZE)
    left_edge = ImageOps.mirror(
        foreground.crop((0, 0, EDGE_SOURCE_WIDTH, FOREGROUND_SIZE))
    ).resize((SIDE_WIDTH, FOREGROUND_SIZE), Image.Resampling.LANCZOS)
    right_edge = ImageOps.mirror(
        foreground.crop(
            (FOREGROUND_SIZE - EDGE_SOURCE_WIDTH, 0,
             FOREGROUND_SIZE, FOREGROUND_SIZE)
        )
    ).resize((SIDE_WIDTH, FOREGROUND_SIZE), Image.Resampling.LANCZOS)
    fullscreen.paste(left_edge, (0, 0))
    fullscreen.paste(foreground, (SIDE_WIDTH, 0))
    fullscreen.paste(right_edge, (SIDE_WIDTH + FOREGROUND_SIZE, 0))
    fullscreen.save(target, "BMP")


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
