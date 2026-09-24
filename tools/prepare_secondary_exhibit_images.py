"""Prepare the five supplied 4:3 exhibit pages for the 960x540 TF image slots."""

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/secondary_exhibit_source"
OUTPUT = ROOT / "assets/secondary_exhibit_tf"
PREVIEW = ROOT / "assets/secondary_exhibit_preview"
NAMES = ("越王勾践剑", "四羊方尊", "金缕玉衣", "马踏飞燕", "长信宫灯")
SIZE = (960, 540)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(NAMES):
        with Image.open(SOURCE / f"{name}.png") as source:
            image = source.convert("RGB")
            backdrop = ImageOps.fit(image, SIZE, method=Image.Resampling.LANCZOS)
            backdrop = ImageEnhance.Brightness(backdrop.filter(ImageFilter.GaussianBlur(24))).enhance(0.8)
            page = ImageOps.contain(image, SIZE, method=Image.Resampling.LANCZOS)
            backdrop.paste(page, ((SIZE[0] - page.width) // 2, (SIZE[1] - page.height) // 2))
            bmp_path = OUTPUT / f"IMAGE{index}.BMP"
            backdrop.save(bmp_path, format="BMP")
            backdrop.save(PREVIEW / f"IMAGE{index}.png", format="PNG")
            with Image.open(bmp_path) as check:
                assert check.size == SIZE and check.mode == "RGB"


if __name__ == "__main__":
    main()
