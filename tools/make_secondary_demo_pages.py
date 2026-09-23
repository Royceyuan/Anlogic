from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "assets/secondary_demo/fictional_museum_map.png"
OUT = ROOT / "assets/secondary_demo_tf"
FONT = Path("C:/Windows/Fonts/simhei.ttf")
NAMES = ("越王勾践剑", "四羊方尊", "金缕玉衣", "马踏飞燕", "长信宫灯")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with Image.open(MAP) as source:
        map_image = ImageOps.contain(source.convert("RGB"), (410, 280))
    title = ImageFont.truetype(str(FONT), 40)
    body = ImageFont.truetype(str(FONT), 24)
    small = ImageFont.truetype(str(FONT), 19)

    for index, name in enumerate(NAMES):
        image = Image.new("RGB", (960, 540), "#101c2d")
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 959, 88), fill="#20364c")
        draw.rectangle((0, 86, 959, 89), fill="#d9b765")
        draw.text((30, 20), name, font=title, fill="white")
        draw.text((715, 34), f"第 {index + 1} / 5 页", font=small, fill="#e0c77e")

        draw.rectangle((28, 112, 492, 458), outline="#9d8147", width=3)
        draw.rectangle((44, 128, 476, 296), fill="#28394b")
        draw.text((135, 187), "文物图片占位", font=body, fill="#cad5dd")
        draw.text((48, 321), f"展柜：演示 A{index + 1:02d}", font=body, fill="#f3ead8")
        draw.text((48, 369), "简介：副屏信息页演示素材", font=body, fill="#f3ead8")
        draw.text((48, 414), "正式展示时替换为审核后的图文", font=small, fill="#b5c4cb")

        draw.rectangle((516, 112, 930, 458), outline="#9d8147", width=3)
        draw.text((538, 122), "展厅示意 / 当前位置至出口", font=small, fill="#f3ead8")
        image.paste(map_image, (518 + (410 - map_image.width) // 2,
                                164 + (280 - map_image.height) // 2))
        draw.rectangle((0, 480, 959, 539), fill="#0a1322")
        draw.text((30, 492), "演示地图和路线 · 非真实疏散指引", font=small, fill="#f0d281")
        path = OUT / f"IMAGE{index}.BMP"
        image.save(path, format="BMP")
        with Image.open(path) as check:
            assert check.size == (960, 540) and check.mode == "RGB"
        print(path)


if __name__ == "__main__":
    main()
