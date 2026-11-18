#!/usr/bin/env python3
"""產生佔位的 App 圖示（Phase 0）：黛青到墨黑的漸層底，中間是金色圓丹與外環。

用法：py tools/make_placeholder_icon.py
輸出：Xiulian/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png（1024×1024、不透明 RGB）

正式圖示導入時（tools/import_art.py）會覆蓋這張圖。需要 Pillow：py -m pip install pillow
"""
import pathlib
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("需要 Pillow，請先執行：py -m pip install pillow")
    sys.exit(2)

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Xiulian" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
SCALE = 4                     # 先畫 4 倍大再縮小，圓的邊緣比較平滑
INK = (0x15, 0x17, 0x1C)      # 墨黑
DAI = (0x23, 0x32, 0x4A)      # 黛青
GOLD = (0xD4, 0xA8, 0x4B)     # 金
RESAMPLE = getattr(Image, "Resampling", Image).LANCZOS


def blend(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def circle(draw, center, radius, **kwargs):
    draw.ellipse([center - radius, center - radius, center + radius, center + radius], **kwargs)


def main():
    big = SIZE * SCALE
    image = Image.new("RGB", (big, big), INK)
    draw = ImageDraw.Draw(image)
    for y in range(big):  # 由上往下：黛青 → 墨黑
        draw.line([(0, y), (big - 1, y)], fill=blend(DAI, INK, y / (big - 1)))

    center = big / 2
    circle(draw, center, big * 0.36, outline=GOLD, width=round(big * 0.02))  # 外環
    circle(draw, center, big * 0.24, fill=GOLD)                              # 圓丹

    icon = image.resize((SIZE, SIZE), RESAMPLE)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, "PNG", optimize=True)
    print(f"已產生 {OUT.relative_to(ROOT).as_posix()}（{icon.width}x{icon.height}，{icon.mode}）")


if __name__ == "__main__":
    main()
