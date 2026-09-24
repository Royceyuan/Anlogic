"""Prepare the future rolling-cache SD package: 720p heroes, 540p info pages."""

from pathlib import Path
from shutil import copyfile

from PIL import Image, ImageOps


ASSETS = Path(__file__).resolve().parents[1] / "assets"
NAMES = ("越王勾践剑", "四羊方尊", "金缕玉衣", "马踏飞燕", "长信宫灯")
OUTPUT = ASSETS / "secondary_exhibit_720p_tf"


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    for index, name in enumerate(NAMES):
        with Image.open(ASSETS / "secondary_exhibit_hero_source" / f"{name}.png") as source:
            hero = ImageOps.fit(source.convert("RGB"), (1280, 720), Image.Resampling.LANCZOS)
            hero.save(OUTPUT / f"IMAGE{index}.BMP", format="BMP")
        copyfile(ASSETS / "secondary_exhibit_tf" / f"IMAGE{index}.BMP",
                 OUTPUT / f"IMAGE{index + 5}.BMP")
    for index in range(10):
        with Image.open(OUTPUT / f"IMAGE{index}.BMP") as image:
            assert image.mode == "RGB"
            assert image.size == ((1280, 720) if index < 5 else (960, 540))


if __name__ == "__main__":
    main()
