"""Prepare source-derived 720p exhibit images."""

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


ASSETS = Path(__file__).resolve().parents[1] / "assets"
NAMES = ("越王勾践剑", "四羊方尊", "金缕玉衣", "马踏飞燕", "长信宫灯")
OUTPUT = ASSETS / "secondary_exhibit_720p_tf"


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    for index, name in enumerate(NAMES):
        with Image.open(ASSETS / "secondary_exhibit_hero_source" / f"{name}.png") as source:
            hero = ImageOps.fit(source.convert("RGB"), (1280, 720), Image.Resampling.LANCZOS)
            hero.save(OUTPUT / f"IMAGE{index}.BMP", format="BMP")
        with Image.open(ASSETS / "secondary_exhibit_source" / f"{name}.png") as source:
            original = source.convert("RGB")
            backdrop = ImageOps.fit(original, (1280, 720), Image.Resampling.LANCZOS)
            backdrop = ImageEnhance.Brightness(backdrop.filter(ImageFilter.GaussianBlur(32))).enhance(0.8)
            page = ImageOps.contain(original, (1280, 720), Image.Resampling.LANCZOS)
            backdrop.paste(page, ((1280 - page.width) // 2, (720 - page.height) // 2))
            backdrop.save(OUTPUT / f"IMAGE{index + 5}.BMP", format="BMP")
    for index in range(10):
        with Image.open(OUTPUT / f"IMAGE{index}.BMP") as image:
            assert image.mode == "RGB"
            assert image.size == (1280, 720)


if __name__ == "__main__":
    main()
