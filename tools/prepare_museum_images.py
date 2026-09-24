from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[2] / "素材"
DEST = Path("E:/")
BACKUP = DEST / "BACKUP_IMAGES_BEFORE_PHOTOREAL_20260924" / "TF_BMP"
MAX_SIZE = (1920, 1080)


def render(source: Path, target: Path) -> None:
    with Image.open(source) as opened:
        image = opened.convert("RGB")
    image.thumbnail(MAX_SIZE, Image.Resampling.LANCZOS)
    image.save(target, "BMP")


def main() -> None:
    artifacts = sorted(path for path in ROOT.iterdir() if path.is_dir())
    outputs = []
    for index, folder in enumerate(artifacts):
        full = folder / "全貌图.png"
        outputs.append((full if full.exists() else folder / "全貌图.jpg",
                        DEST / f"IMAGE{index}.BMP"))
        details = sorted(folder.glob("细节*.png")) or sorted(folder.glob("细节*.jpg"))
        for detail, source in enumerate(details, 1):
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
            assert check.width <= MAX_SIZE[0] and check.height <= MAX_SIZE[1]
            assert check.mode == "RGB"
    print(f"prepared {len(outputs)} images; backup: {BACKUP}")


if __name__ == "__main__":
    main()
