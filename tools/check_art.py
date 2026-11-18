#!/usr/bin/env python3
"""檢查美術原圖是否符合 docs/ART_ASSETS.md 第 4 節與第 5.1 節的技術規格。

用法：
  py tools/check_art.py                   檢查 art/masters/ 裡的全部檔案
  py tools/check_art.py 檔案或資料夾 ...    只檢查指定的檔案或資料夾

需要 Pillow：py -m pip install pillow
只要有一個檔案「不通過」，結束代碼就是 1（環境問題是 2）。
主體對不對、有沒有文字、畫風是否一致由檢測 AI 負責（第 5.2 節）；這裡只檢查程式量得出來的項目。
"""
import difflib
import io
import json
import pathlib
import sys

try:
    from PIL import Image, ImageChops, ImageFilter, ImageStat
except ImportError:
    print("需要 Pillow，請先執行：py -m pip install pillow")
    sys.exit(2)

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "art" / "manifest.json"
MASTERS = ROOT / "art" / "masters"

MAX_BYTES = 5 * 1024 * 1024
RATIO_TOLERANCE = 0.01   # 比例誤差上限
SIZE_TOLERANCE = 0.98    # 寬、高至少要有規格的 98%
SUBJECT_ALPHA = 16       # alpha 大於這個值才算主體
CORNER_ALPHA = 8         # 去背圖四個角落允許的最大 alpha
HALO_DISTANCE = 24       # 主體最外圈的顏色和生成背景色相差在這個值以內，算殘留背景色
HALO_RATIO = 0.5         # 最外圈有超過這個比例是殘留背景色就提醒
HALO_MIN_PIXELS = 200    # 最外圈太少時不判斷
SUFFIX_FORMAT = {".png": "PNG", ".jpg": "JPEG", ".jpeg": "JPEG"}
IGNORED_NAMES = {"thumbs.db", "desktop.ini"}
SIDE = {"top": "上", "bottom": "下", "left": "左", "right": "右"}
AXIS = {"width": "寬度", "height": "高度", "max": "最長邊"}


def hex_rgb(code):
    return tuple(int(code[i:i + 2], 16) for i in (1, 3, 5))


def has_alpha(im):
    return im.mode in ("RGBA", "LA", "PA", "RGBa", "La") or "transparency" in im.info


def png_bit_depth(path):
    with open(path, "rb") as f:
        head = f.read(26)
    if head[:8] == b"\x89PNG\r\n\x1a\n" and head[12:16] == b"IHDR":
        return head[24]
    return None


def icc_name(icc):
    try:
        from PIL import ImageCms
        name = ImageCms.getProfileDescription(ImageCms.ImageCmsProfile(io.BytesIO(icc)))
        return name.strip() or "不明"
    except Exception:  # noqa: BLE001 - 沒有 ImageCms 或描述檔損壞時，直接在位元組裡找名稱
        for name in ("sRGB", "Display P3", "Adobe RGB"):
            if name.encode() in icc or name.encode("utf-16-be") in icc:
                return name
        return "不明"


def is_boundary(text, index):
    """text[index] 是否是檔名的分界（結尾，或不是英文字母、數字）。"""
    return index >= len(text) or not (text[index].isascii() and text[index].isalnum())


def suggest_name(path, assets):
    lower = path.stem.lower()
    suffix = path.suffix.lower() if path.suffix.lower() in SUFFIX_FORMAT else ".png"
    for ext in SUFFIX_FORMAT:
        if lower.endswith(ext) and lower[: -len(ext)] in assets:
            return f"副檔名重複了（Windows 預設會隱藏副檔名），請改成 {lower[: -len(ext)]}{suffix}"
    if lower in assets:
        return f"檔名要全部小寫：{lower}{suffix}"
    prefixes = [i for i in assets if lower.startswith(i) and is_boundary(lower, len(i))]
    guesses = [max(prefixes, key=len)] if prefixes else difflib.get_close_matches(lower, list(assets), n=1, cutoff=0.75)
    if guesses:
        return f"檔名不在清單裡，是不是要改成 {guesses[0]}{suffix}？"
    return "檔名不在清單裡（請對照 docs/ART_ASSETS.md 第 9.1 節）"


def check_cutout(im, asset, cat, fails, warns):
    """需要去背的類別：透明通道、四個角落、主體位置與大小、殘留背景色。"""
    if not has_alpha(im):
        fails.append("沒有透明背景（還沒去背，或存檔時沒有存成透明 PNG）")
        return
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    w, h = rgba.size

    # 主體範圍：先用 3×3 侵蝕去掉零星的小雜點
    mask = alpha.point(lambda a: 255 if a > SUBJECT_ALPHA else 0)
    core = mask.filter(ImageFilter.MinFilter(3))
    bbox = core.getbbox()
    if bbox is None:
        fails.append("整張幾乎都是透明的，找不到主體")
        return
    left, top, right, bottom = bbox

    c = max(4, round(min(w, h) * 0.01))
    corners = [(0, 0, c, c), (w - c, 0, w, c), (0, h - c, c, h), (w - c, h - c, w, h)]
    if any(alpha.crop(box).getextrema()[1] > CORNER_ALPHA for box in corners):
        if right - left >= w * 0.99 and bottom - top >= h * 0.99:
            fails.append("背景沒有去掉：四個角落和邊緣都不透明")
            return
        fails.append("四個角落沒有完全透明（背景沒去乾淨，或主體碰到角落）")

    space = {"top": top / h, "bottom": (h - bottom) / h, "left": left / w, "right": (w - right) / w}
    tight = [f"{SIDE[side]} {space[side] * 100:.1f}%（至少 {minimum * 100:g}%）"
             for side, minimum in (cat["check"].get("margins") or {}).items()
             if minimum > 0 and space[side] < minimum - 1e-9]
    if tight:
        fails.append("主體太靠近畫面邊緣，留白不夠：" + "、".join(tight))

    fill = cat["check"].get("fill")
    if fill:
        bw, bh = (right - left) / w, (bottom - top) / h
        value = {"width": bw, "height": bh, "max": max(bw, bh)}[fill["axis"]]
        if not fill["min"] <= value <= fill["max"]:
            warns.append(f"主體{AXIS[fill['axis']]}佔畫面 {value * 100:.0f}%，"
                         f"建議在 {fill['min'] * 100:.0f}%–{fill['max'] * 100:.0f}% 之間")

    # 殘留背景色：主體最外圈的像素如果大多是生成背景的顏色，就是白邊或灰邊
    if asset.get("gen_bg"):
        ring = ImageChops.subtract(mask, core)
        ring_count = ring.histogram()[255]
        if ring_count >= HALO_MIN_PIXELS:
            diff = ImageChops.difference(rgba.convert("RGB"), Image.new("RGB", (w, h), hex_rgb(asset["gen_bg"])))
            r, g, b = diff.split()
            distance = ImageChops.lighter(ImageChops.lighter(r, g), b)
            near_bg = distance.point(lambda d: 255 if d <= HALO_DISTANCE else 0)
            halo = ImageChops.multiply(ring, near_bg).histogram()[255]
            if halo / ring_count > HALO_RATIO:
                color = "白邊" if asset["gen_bg"].upper() == "#FFFFFF" else "灰邊"
                warns.append(f"主體邊緣可能殘留{color}（{halo / ring_count * 100:.0f}% 的外圈像素是背景色），請放大檢查")


def check_opaque(im, asset, fails, warns):
    """不用去背的類別（App 圖示、背景、卡片背面）：不能有透明的地方。"""
    if has_alpha(im):
        if im.convert("RGBA").getchannel("A").getextrema()[0] < 255:
            fails.append("有透明的地方；這類圖要整張不透明，不用去背")
            return
        if asset["category"] == "icon":
            warns.append("App 圖示帶有透明通道（雖然沒有透明的地方），導入時會自動移除")
    if asset["category"] == "icon":
        rgb = im.convert("RGB")
        w, h = rgb.size
        c = max(8, round(min(w, h) * 0.03))
        boxes = [(0, 0, c, c), (w - c, 0, w, c), (0, h - c, c, h), (w - c, h - c, w, h)]
        stats = [ImageStat.Stat(rgb.crop(box)) for box in boxes]
        if all(min(s.mean) >= 240 and max(s.stddev) < 4 for s in stats):
            warns.append("四個角都是純白：可能把圓角圖示或白色底畫進去了。"
                         "App 圖示要整張填滿背景，圓角由 iOS 自動裁")


def inspect(im, path, suffix, asset, cat, fails, warns):
    if suffix and im.format != SUFFIX_FORMAT[suffix]:
        fails.append(f"副檔名是 {suffix}，實際內容卻是 {im.format}。只改副檔名不算轉檔，"
                     "請用小畫家開啟後「另存新檔」成 PNG")

    if im.mode in ("CMYK", "LAB", "HSV", "YCbCr"):
        fails.append(f"色彩模式是 {im.mode}，要轉成 RGB")
    depth = png_bit_depth(path) if im.format == "PNG" else None
    if (depth and depth > 8) or im.mode.startswith("I") or im.mode == "F":
        warns.append("這張是 16 位元色彩，建議轉成 8 位元（導入時也會自動轉）")
    icc = im.info.get("icc_profile")
    if icc:
        name = icc_name(icc)
        if "srgb" not in name.lower():
            warns.append(f"色彩描述檔是「{name}」不是 sRGB，顏色可能會偏，建議轉成 sRGB")

    w, h = im.size
    if not any(abs((w / h) / (a / b) - 1) <= RATIO_TOLERANCE for a, b in cat["aspects"]):
        fails.append(f"比例不對：{w}×{h}，應該是{cat['ratio']}")
    if w < cat["width"] * SIZE_TOLERANCE or h < cat["height"] * SIZE_TOLERANCE:
        fails.append(f"尺寸太小：{w}×{h}，寬至少 {cat['width']}、高至少 {cat['height']}"
                     "（線上去背工具的免費版常會把圖縮小）")

    if cat["transparent"]:
        check_cutout(im, asset, cat, fails, warns)
    else:
        check_opaque(im, asset, fails, warns)


def check_file(path, asset, cat):
    fails, warns = [], []
    suffix = path.suffix.lower()
    allowed = [".png"] + ([".jpg", ".jpeg"] if cat["allow_jpeg"] else [])
    if suffix not in allowed:
        fails.append(f"檔案類型是 {path.suffix or '（沒有副檔名）'}，要轉成 PNG"
                     + ("（背景也可以用 JPG）" if cat["allow_jpeg"] else ""))
        suffix = None

    size = path.stat().st_size
    if size > MAX_BYTES:
        warns.append(f"檔案 {size / 1048576:.1f} MB，超過 5 MB，建議壓縮（例如 TinyPNG）")

    try:
        im = Image.open(path)
        im.load()
    except Exception as e:  # noqa: BLE001 - 任何解碼問題都回報給使用者
        fails.append(f"打不開這張圖（{e}）")
        return fails, warns
    try:
        inspect(im, path, suffix, asset, cat, fails, warns)
    finally:
        im.close()
    return fails, warns


def collect(args):
    """回傳（要檢查的檔案, 是否檢查了整個資料夾）。"""
    targets = [pathlib.Path(a) for a in args] or [MASTERS]
    files, whole_folder = [], False
    for target in targets:
        if target.is_dir():
            whole_folder = True
            files += sorted(p for p in target.iterdir()
                            if p.is_file() and not p.name.startswith(".") and p.name.lower() not in IGNORED_NAMES)
        else:
            files.append(target)
    return files, whole_folder


def main(argv):
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    try:
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)
    except (OSError, ValueError) as e:
        print(f"讀不到 {MANIFEST}：{e}")
        return 2
    assets = {a["id"]: a for a in manifest["assets"]}
    cats = manifest["categories"]

    if not argv and not MASTERS.is_dir():
        print("找不到 art/masters 資料夾。")
        return 1
    files, whole_folder = collect(argv)

    passed = failed = 0
    seen = {}
    for path in files:
        fails, warns, label = [], [], path.name
        if not path.is_file():
            fails.append("找不到這個檔案")
        elif path.stem not in assets:
            fails.append(suggest_name(path, assets))
        elif path.stem in seen:
            fails.append(f"和 {seen[path.stem]} 是同一張圖，請只留一個檔案")
        else:
            seen[path.stem] = path.name
            asset = assets[path.stem]
            label = f"{path.name}（{asset['name']}）"
            fails, warns = check_file(path, asset, cats[asset["category"]])

        status = "不通過" if fails else ("通過，有提醒" if warns else "通過")
        print(f"[{status}] {label}")
        for msg in fails:
            print(f"    不通過：{msg}")
        for msg in warns:
            print(f"    提醒：{msg}")
        failed += bool(fails)
        passed += not fails

    print()
    if not files:
        print("沒有找到任何檔案。")
    else:
        print(f"共 {len(files)} 個檔案：通過 {passed} 個，不通過 {failed} 個。")
    if whole_folder:
        p1 = [a["id"] for a in manifest["assets"] if a["priority"] == "P1"]
        p2 = [a["id"] for a in manifest["assets"] if a["priority"] == "P2"]
        missing = [i for i in p1 if i not in seen]
        print(f"進度：第一版（P1）{len(p1) - len(missing)}/{len(p1)} 張，"
              f"之後（P2）{sum(i in seen for i in p2)}/{len(p2)} 張。")
        if missing:
            print("第一版還沒有檔案的：" + "、".join(missing))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
