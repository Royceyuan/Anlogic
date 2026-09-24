"""Build five hero pages and five matching information pages for the TF root."""

from pathlib import Path
from shutil import copyfile

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1] / "assets"
HERO = ROOT / "secondary_exhibit_hero_source"
INFO = ROOT / "secondary_exhibit_tf"
OUTPUT = ROOT / "secondary_exhibit_v2_tf"
NAMES = ("越王勾践剑", "四羊方尊", "金缕玉衣", "马踏飞燕", "长信宫灯")


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    for index, name in enumerate(NAMES):
        with Image.open(HERO / f"{name}.png") as source:
            image = ImageOps.fit(source.convert("RGB"), (960, 540), Image.Resampling.LANCZOS)
            image.save(OUTPUT / f"IMAGE{index}.BMP", format="BMP")
        copyfile(INFO / f"IMAGE{index}.BMP", OUTPUT / f"IMAGE{index + 5}.BMP")
    for index in range(10):
        with Image.open(OUTPUT / f"IMAGE{index}.BMP") as image:
            assert image.size == (960, 540) and image.mode == "RGB"


if __name__ == "__main__":
    main()
