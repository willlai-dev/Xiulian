#!/usr/bin/env python3
"""依 art/manifest.json 產生 docs/ART_ASSETS.md（美術製作規格）。

用法：py tools/build_art_doc.py
修改美術清單或提示詞時，改 art/manifest.json 後重新執行，不要直接改 docs/ART_ASSETS.md。
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "art" / "manifest.json"
OUT = ROOT / "docs" / "ART_ASSETS.md"

CATEGORY_ORDER = ["icon", "avatar", "master", "badge", "chest", "item", "object", "scroll",
                  "background", "equip", "tech", "root", "card"]
ANCHOR_LABEL = {"avatar": "角色類", "badge": "徽章類", "item": "道具類", "background": "背景類"}
BG_NAME = {"#FFFFFF": "純白（#FFFFFF）", "#808080": "中性灰（#808080）"}

QA_ITEMS = [
    ("主體正確", "必須", "畫的是「主體描述」中的東西，「必要特徵」全部都有。"),
    ("沒有文字", "必須", "畫面中沒有任何文字、字母、數字、印章字、簽名或浮水印；符紙、令牌、牌坊、書封上的圖案也不能像文字。"),
    ("沒有特效", "必須", "沒有光暈、光束、粒子、煙霧或閃光（背景與 App 圖示除外）。"),
    ("構圖完整", "必須", "主體的位置與大小符合規格；主體完整，沒有被畫面邊緣切到（立繪要包含雙腳）。"),
    ("背景乾淨", "必須", "需要去背的圖：背景是乾淨的單色平塗（或已經是透明），沒有地面、影子、漸層或雜物；去背後邊緣沒有白邊或灰邊。"),
    ("結構正確", "必須", "人物五官端正、手指數量正確、沒有多出或缺少的肢體；物品結構合理，該對稱的地方對稱。"),
    ("沒有 AI 瑕疵", "必須", "沒有扭曲、融化、重複或莫名其妙的細節；沒有明顯的雜訊或模糊。"),
    ("原創且合宜", "必須", "不像任何知名遊戲、動畫或品牌的角色與標誌；沒有血腥、暴力、裸露等不適合的內容。"),
    ("風格一致", "必須", "和同類基準圖相比，筆觸、配色、光源（左上）與視角一致；立繪必須是同一個角色。基準圖本身這項直接算 PASS。"),
    ("縮小可讀", "建議", "縮小到手機上的實際大小（徽章約 64 像素、道具約 128 像素、App 圖示約 60 像素）仍然一眼認得出來。"),
    ("色彩合宜", "建議", "主色符合描述（例如品質色）；整體不過度飽和、不偏螢光。"),
]

TROUBLESHOOTING = [
    ("圖裡出現文字或像文字的符號", "加上「畫面中完全不要有任何文字、字母、數字，也不要像文字的筆畫」"),
    ("出現光暈、煙霧或閃光", "加上「不要任何發光、光暈、煙霧或粒子效果，主體邊緣要乾淨俐落」"),
    ("主體被裁切或太靠近邊緣", "加上「主體完整入鏡，四周保留空白」"),
    ("主體太大或太小", "加上「主體約佔畫面的 N%」（N 照這張檢測卡的「主體大小與位置」）"),
    ("背景有地面、影子或漸層", "加上「純色平塗背景，沒有地面、沒有影子、沒有漸層」"),
    ("立繪換了一個人", "附上 `avatar_realm_1`，並加上「和附圖是同一個角色，臉、髮型、身形完全一樣，只換服裝與配件」"),
    ("手指或肢體怪異", "加上「手部自然、五根手指、比例正確」，或改成「雙手藏在袖子裡」"),
    ("和其他圖的畫風不一致", "附上同類的基準圖，並加上「沿用附圖的筆觸、配色、光源與視角」"),
    ("顏色太鮮豔或偏螢光", "加上「色調沉穩，降低飽和度」"),
    ("物品不是單獨一個", "加上「畫面中只有一個物件，不要其他物品或裝飾」"),
    ("視角不對", "加上「3/4 俯視角，大約從上方 30 度往下看」"),
]


def load():
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def anchor_of(m, a):
    key = m["category_anchor"].get(a["category"])
    return (key, m["anchors"][key]) if key else (None, None)


def background_text(m, a, cat):
    if cat["transparent"]:
        return m["background_words"][a["gen_bg"]]
    return cat["background"]


def reference_text(m, a):
    key, anchor = anchor_of(m, a)
    if anchor is None:
        return "不需要參考圖。"
    if a["id"] == anchor:
        return f"這張是{ANCHOR_LABEL[key]}的基準圖，不需要參考圖。"
    if a["category"] == "avatar":
        return "附上的是這個角色的第一張立繪：請畫成同一個角色（臉、髮型、身形完全一樣），只改變服裝與配件，畫風也要一致。"
    if a["category"] == "master":
        return "附上的是一張角色立繪：請沿用它的畫風與光源（這次畫的是另一個人物）。"
    if a["category"] == "badge":
        return f"請沿用附上的基準圖（{anchor}）的外框、畫風與配色，只改變中央圖案。"
    if a["category"] == "background":
        return f"請沿用附上的基準圖（{anchor}）的畫風與色調。"
    return f"請沿用附上的基準圖（{anchor}）的畫風、光源與視角。"


def generation_prompt(m, a):
    cat = m["categories"][a["category"]]
    lines = [f"請畫一張{cat['usage_phrase']}。"]
    if a["category"] == "avatar":
        lines.append(f"角色：{m['character']}")
    lines += [
        f"主體：{a['subject']}",
        f"風格：{m['style']}",
        f"構圖：{cat['composition']}",
        f"背景：{background_text(m, a, cat)}",
        f"畫面比例：{cat['ratio']}（{cat['width']}×{cat['height']} 像素）。",
        f"參考：{reference_text(m, a)}",
        f"不要：{cat.get('forbid', m['forbid_default'])}",
    ]
    return "\n".join(lines)


def check_card(m, a):
    cat = m["categories"][a["category"]]
    key, anchor = anchor_of(m, a)
    if anchor is None:
        ref = "不需要（第 9 項直接算 PASS）"
    elif a["id"] == anchor:
        ref = f"這張就是{ANCHOR_LABEL[key]}的基準圖（第 9 項直接算 PASS）"
    elif a["category"] == "avatar":
        ref = f"請和附上的 {anchor} 比較，必須是同一個角色"
    else:
        ref = f"請和附上的 {anchor} 比較畫風"
    bg = "需要去背（交付透明 PNG）" if cat["transparent"] else "不透明，不用去背"
    lines = [
        f"【檢測卡】{a['id']}（{a['name']}）",
        f"類別：{cat['name']}｜{cat['ratio']}｜{bg}",
        f"用途：{a['usage']}",
        f"主體描述：{a['subject']}",
        f"主體大小與位置：{cat['composition']}",
        "必要特徵：",
        *[f"- {x}" for x in a["must"]],
        f"基準圖：{ref}",
    ]
    return "\n".join(lines)


def spec_line(m, a):
    cat = m["categories"][a["category"]]
    size = f"{cat['ratio']}，至少 {cat['width']}×{cat['height']}"
    if cat["transparent"]:
        bg = f"生成時用{BG_NAME[a['gen_bg']]}背景，交付時去背成透明 PNG"
    else:
        bg = "不透明，不用去背"
    return f"{cat['file']}｜{size}｜{bg}"


def build(m):
    cats = m["categories"]
    assets = m["assets"]
    by_cat = {c: [a for a in assets if a["category"] == c] for c in CATEGORY_ORDER}
    p1 = sum(1 for a in assets if a["priority"] == "P1")
    p2 = len(assets) - p1
    anchors = m["anchors"]
    out = []
    w = out.append

    w("# 修練 — 美術製作規格（ART_ASSETS）\n")
    w("> 給「AI 生圖 → AI 檢測 → Claude Code 導入」的流程使用。")
    w("> 這份文件由 `tools/build_art_doc.py` 依 `art/manifest.json` 產生。"
      "要修改清單或提示詞，請改 manifest 後重新執行 `py tools/build_art_doc.py`，不要直接改這份文件。\n")

    # 0
    w("## 0. 分工與流程\n")
    w("| 角色 | 負責 |")
    w("|---|---|")
    w("| 你 | 用生圖 AI 一張一張生成；需要時去背、轉成 PNG、改檔名 |")
    w("| 檢測 AI | 依第 5 節的標準逐項檢查，給出通過或不通過 |")
    w("| Claude Code | 用程式檢查技術規格、縮放並放進 app、用程式做所有動態特效 |\n")
    w("每一張圖的流程：\n")
    w("1. 複製這張的「生成提示詞」（第 9 節）貼給生圖 AI，並附上同類的基準圖（第 3.6 節）。")
    w("2. 不滿意就重新生成；同一張最多試 5 次，還是不行就把檢測結果貼給 Claude，請它修改提示詞。")
    w("3. 需要去背的圖，去背後存成 PNG（第 4.3 節）。")
    w("4. 改成清單上的檔名，例如 `item_bt_zhuji.png`。")
    w("5. 開一個檢測 AI 的對話，先貼一次「檢測 AI 開場設定」（第 5.3 節）；之後每一張貼上它的「檢測卡」，並附上圖片。")
    w("6. 通過的圖放進 repo 的 `art/masters/`，在第 9.1 節的總表打勾。想先確認尺寸與透明背景，可以自己跑技術檢查（第 8 節）。")
    w("7. 累積一批後告訴 Claude Code：「導入美術」，它會接手（第 8 節）。\n")

    # 1
    w("## 1. AI 只畫靜態主圖，特效交給程式\n")
    w("AI 生成的圖一律是**靜態、乾淨的主體**。不要在圖裡畫光暈、光束、粒子、煙霧、閃電這類特效：")
    w("這些由程式疊加，才能做成動畫、依品質換顏色，也比較好去背。\n")
    w("| 圖片 | 程式會加上的效果 |")
    w("|---|---|")
    for c in CATEGORY_ORDER:
        w(f"| {cats[c]['name']} | {cats[c]['effects']} |")
    w("")
    w("完全由程式繪製、不需要圖片的東西：進度環、修為條、周天念珠、天雷與閃電、浮字、品質外框與光暈、所有文字。\n")

    # 2
    w("## 2. 數量總覽\n")
    w("| 類別 | 第一版（P1） | 之後（P2） | 合計 | 檔案類型 | 尺寸 | 去背 |")
    w("|---|---|---|---|---|---|---|")
    for c in CATEGORY_ORDER:
        lst = by_cat[c]
        n1 = sum(1 for a in lst if a["priority"] == "P1")
        cat = cats[c]
        size = f"{cat['width']}×{cat['height']}" + (" 以上" if c == "background" else "")
        w(f"| {cat['name']} | {n1} | {len(lst) - n1} | {len(lst)} | {cat['file']} | {size} | "
          f"{'是' if cat['transparent'] else '否'} |")
    w(f"| **合計** | **{p1}** | **{p2}** | **{len(assets)}** | | | |\n")
    w(f"建議順序：先做 {len(anchors)} 張基準圖（第 3.6 節）→ 第一版（P1）其餘 {p1 - len(anchors)} 張 → 之後（P2）{p2} 張。")
    w("P2 的圖在用到之前，app 會先用佔位圖，不影響使用。\n")

    # 3
    w("## 3. 風格指南\n")
    w("### 3.1 共通風格（每張提示詞都已包含）\n")
    w(f"> {m['style']}\n")
    w("### 3.2 色票\n")
    w("| 名稱 | 色碼 | 用在 |")
    w("|---|---|---|")
    for row in [("墨黑", "#15171C", "線條、暗部"), ("黛青", "#23324A", "冷色陰影、背景主色"),
                ("宣紙白", "#EFE8DA", "亮部、紙張"), ("金", "#D4A84B", "點綴、外框"),
                ("朱砂紅", "#B5342A", "少量強調（繩結、印記）"), ("玉青", "#5E9C8F", "玉器、靈氣")]:
        w(f"| {row[0]} | {row[1]} | {row[2]} |")
    w("")
    w("### 3.3 品質色\n")
    w("寶箱與道具的主色會參考品質色；品質光暈與外框由程式依品質上色（GAME_DESIGN 11.1）。\n")
    w("| 品質 | 色碼 |")
    w("|---|---|")
    for q, h in [("凡品", "#B8B8B8"), ("靈品", "#4CAF50"), ("玄品", "#3F8EFC"),
                 ("地品", "#A259FF"), ("天品", "#F5B700"), ("仙品", "#FF4D4F")]:
        w(f"| {q} | {h} |")
    w("")
    w("### 3.4 光源與視角\n")
    w("- 光源固定在左上方。")
    w("- 寶箱、道具、法寶、功法、介面道具：3/4 俯視角，大約從上方 30 度往下看。")
    w("- 立繪與師父：身體 3/4 側向畫面右方（介面上人物在左、文字在右）。")
    w("- 徽章、靈珠、卷軸：正面平視。\n")
    w("### 3.5 角色設定（所有立繪必須一致）\n")
    w(f"> {m['character']}\n")
    w("- 各境界的服裝與配件寫在第 9 節每一張的主體描述裡；境界的光環與特效由程式加上。")
    w("- 先寫成看不出性別的修士，方便以後分享給朋友。想改成明確的男性或女性角色，請 Claude 修改 manifest 的角色設定。\n")
    w("### 3.6 基準圖\n")
    w("先做這幾張，檢測通過後，之後同類的圖生成時都附上它當參考，畫風才會一致。\n")
    w("| 基準圖 | 用在哪些類別 | 之後生成時 |")
    w("|---|---|---|")
    rows = {
        "avatar": ("角色立繪、師父插圖", "立繪要求「同一個角色」；師父只參考畫風"),
        "badge": ("境界徽章、卡片背面", "要求相同外框、畫風與配色"),
        "item": ("寶箱、道具、介面道具、卷軸、法寶、功法、靈珠", "要求相同畫風、光源與視角"),
        "background": ("背景", "要求相同畫風與色調"),
    }
    for key in ["avatar", "badge", "item", "background"]:
        w(f"| `{anchors[key]}` | {rows[key][0]} | {rows[key][1]} |")
    w("| — | App 圖示 | 獨立設計，不用參考圖 |\n")

    # 4
    w("## 4. 技術規格\n")
    w("### 4.1 檔案\n")
    w("- **檔案類型**：PNG；背景圖也可以用 JPG（品質 90 以上）。不要 WebP、HEIC、PSD、SVG。")
    w("- **色彩**：8 位元、sRGB。工具輸出 Display P3 或 16 位元時，請轉成 8 位元 sRGB。")
    w("- **尺寸**：不能小於規格；可以更大，但比例要一樣（例如 2048×3072）。")
    w("- **檔名**：照清單的 id，全小寫英文與底線，例如 `item_bt_zhuji.png`。")
    w("- **檔案大小**：單張 5 MB 以內；太大可以用 TinyPNG 之類的工具壓縮。")
    w("- **重做**：同一張要重做時，用相同檔名覆蓋。")
    w("- **縮圖**：你不需要做縮圖或多種尺寸，Claude Code 會依畫面需要產生。\n")
    w("### 4.2 各類別的規格\n")
    w("| 類別 | 比例與最小尺寸 | 主體大小 | 交付 |")
    w("|---|---|---|---|")
    for c in CATEGORY_ORDER:
        cat = cats[c]
        deliver = "透明 PNG" if cat["transparent"] else cat["file"]
        w(f"| {cat['name']} | {cat['ratio']}，{cat['width']}×{cat['height']} | {cat['subject_size']} | {deliver} |")
    w("")
    w("### 4.3 去背\n")
    w("- **生成時**：用每張規格指定的純色平塗背景，純白（#FFFFFF）或中性灰（#808080）；淺色的主體用灰色比較好去背。")
    w("  工具能直接輸出透明背景 PNG 的話，也可以直接要求透明背景。")
    w("- **去背工具**：Windows 11 小畫家的「移除背景」（免費，保留原尺寸），或 Photoshop 等影像軟體。")
    w("  小畫家：開啟圖片 → 按工具列的「移除背景」→ 放大檢查邊緣，需要時用橡皮擦修 →「另存新檔」選 PNG。")
    w("- **畫布維持原尺寸**：去背只是把背景變透明，不要裁切或縮小。線上去背服務的免費版常會把下載的圖縮小"
      "（例如只給約 625×400 的預覽），手機內建的去背也可能把畫布裁到只剩主體；這兩種都會不符合尺寸與留白。")
    w("- **去背後確認**：")
    w("  - 四個角落完全透明。")
    w("  - 主體邊緣沒有殘留白邊或灰邊，也沒有鋸齒。")
    w("  - 主體和背景之間的空隙要透明，例如兩腳之間、手臂和身體之間。")
    w("  - 主體本身沒有被挖掉，例如白色衣服、白色花紋都還在。")
    w("  - 沒有殘留的影子或背景碎片。")
    w("- **不需要去背**：App 圖示、背景、卡片背面。\n")

    # 5
    w("## 5. 品質檢測標準\n")
    w("### 5.1 技術檢查（程式負責）\n")
    w("檢測 AI 看不出精確的像素尺寸與透明通道，所以這部分由程式檢查。")
    w("Claude Code 導入前會執行 `tools/check_art.py`；你也可以自己先跑（見第 8 節）。")
    w("各類別的最小留白與主體大小範圍，寫在 `art/manifest.json` 每個類別的 `check` 欄位。\n")
    w("| 項目 | 標準 | 不符合時 |")
    w("|---|---|---|")
    for row in [
        ("檔名", "和清單的 id 完全相同（全小寫）；同一張圖只有一個檔案", "不通過，並提示可能的正確檔名"),
        ("檔案類型", "PNG（背景可以是 JPG）；副檔名和實際格式一致", "不通過"),
        ("尺寸與比例", "不小於規格，比例誤差 1% 以內", "不通過"),
        ("色彩", "RGB、8 位元、sRGB", "CMYK 不通過；16 位元或色彩描述檔不是 sRGB 提醒"),
        ("透明", "去背類要有透明背景；App 圖示、背景、卡片背面不能有透明的地方", "不通過"),
        ("四個角落", "去背類完全透明", "不通過"),
        ("主體位置", "和畫布邊緣保持該類別的最小留白（師父插圖的下緣可以切齊畫面）", "不通過"),
        ("主體大小", "在該類別的建議範圍內", "提醒"),
        ("殘留背景色", "主體最外圈沒有大量白邊或灰邊", "提醒"),
        ("App 圖示四角", "不是純白（圖示要整張填滿，圓角由 iOS 裁切）", "提醒"),
        ("檔案大小", "5 MB 以內", "提醒"),
    ]:
        w(f"| {row[0]} | {row[1]} | {row[2]} |")
    w("")
    w("### 5.2 視覺檢查（檢測 AI 負責）\n")
    w("| # | 項目 | 等級 | 標準 |")
    w("|---|---|---|---|")
    for i, (name, level, text) in enumerate(QA_ITEMS, 1):
        w(f"| {i} | {name} | {level} | {text} |")
    w("")
    w("**通過條件**：「必須」全部 PASS，「建議」最多 1 項 FAIL。\n")
    w("### 5.3 檢測 AI 開場設定（每次開新對話時貼一次）\n")
    setup = ["你是手機遊戲「修練」的美術品管。接下來我會一張一張給你圖片和「檢測卡」，請依照下面的標準檢查。",
             "", "【共通標準】"]
    for i, (name, level, text) in enumerate(QA_ITEMS, 1):
        setup.append(f"{i}. {name}（{level}）：{text}")
    setup += ["", "【判定】「必須」全部 PASS，「建議」最多 1 項 FAIL，才算通過。",
              "", "【輸出格式】",
              "1. 用表格逐項回答：項目｜PASS 或 FAIL｜說明。",
              "2. 最後一行寫「結論：通過」或「結論：不通過」。",
              "3. 不通過時，具體建議生成提示詞要怎麼改。",
              "", "我會同時附上同類的基準圖，請用它判斷第 9 項。檢測卡寫「這張就是基準圖」時，第 9 項直接算 PASS。",
              "你看不出精確的像素尺寸與透明通道，這兩項不用判斷，會另外用程式檢查。"]
    w("```text")
    w("\n".join(setup))
    w("```\n")
    w("### 5.4 每張要給檢測 AI 的東西\n")
    w("1. 這張的「檢測卡」文字（第 9 節）。")
    w("2. 要檢測的圖：去背類給去背後的 PNG；App 圖示與背景直接給原圖。")
    w("3. 同類的基準圖（基準圖本身不用）。\n")

    # 6
    w("## 6. 生成提示詞的結構\n")
    w("第 9 節每一張的「生成提示詞」都已經組好，可以直接複製。結構如下，方便你需要時自己調整：\n")
    w("```text")
    w("請畫一張〔用途〕。\n角色：〔只有立繪有〕\n主體：〔這張要畫什麼〕\n風格：〔共通風格〕\n"
      "構圖：〔主體大小、位置、視角〕\n背景：〔純白或中性灰的平塗背景〕\n畫面比例：〔比例與像素〕\n"
      "參考：〔要附上的基準圖〕\n不要：〔文字、特效、現有角色……〕")
    w("```\n")
    w("- 一次只畫一個主體，不要要求一張圖裡畫好幾個道具。")
    w("- 比例要另外設定的工具（例如 Midjourney 的 `--ar 2:3`），記得設定。")
    w("- 生圖工具如果只接受英文，可以先請 ChatGPT 把提示詞翻成英文。")
    w("- 提示詞刻意不寫道具名稱與色碼，避免 AI 把它們當成文字畫進圖裡；色碼只寫在檢測卡。\n")

    # 7
    w("## 7. 常見問題與修正方式\n")
    w("「加上」是指加在生成提示詞的最後一行。\n")
    w("| 問題 | 修正方式 |")
    w("|---|---|")
    for p, fix in TROUBLESHOOTING:
        w(f"| {p} | {fix} |")
    w("")

    # 8
    w("## 8. 交付給 Claude Code\n")
    w("- **放置位置**：repo 的 `art/masters/<id>.png`（背景也可以是 `.jpg`）。")
    w("- **重做**：用相同檔名覆蓋。")
    w("- **通知**：告訴 Claude Code「導入美術」，或列出這次的檔名。它會：")
    w("  1. 執行 `tools/check_art.py`。不通過的圖會告訴你原因並先跳過，其他照常導入；"
      "只有「提醒」的圖照常導入，並轉告提醒內容。")
    w("  2. 依畫面上的實際大小產生縮圖，放進 app 與動態島的 asset catalog（`art/masters/` 的原圖保留不動）。")
    w("  3. 把對應的佔位圖換成正式圖，並在 PR 的手機測試步驟裡說明要看哪裡。")
    w("- **自己先檢查**（選用）：需要 Python 與 Pillow，只要裝一次（裝完 Python 要重新開終端機）。")
    w("  在 repo 資料夾裡執行；可以檢查 `art/masters/`、任何資料夾或單張圖：\n")
    w("```powershell")
    w("winget install Python.Python.3.12")
    w("py -m pip install pillow")
    w("py tools/check_art.py")
    w("py tools/check_art.py D:\\生圖\\待檢查")
    w("py tools/check_art.py art/masters/item_bt_zhuji.png")
    w("```\n")
    w("結果分三種：**通過**；**通過，有提醒**（可以導入，建議看一下）；**不通過**（修正後再檢查一次）。"
      "檢查整個資料夾時，最後會列出第一版（P1）還缺哪些圖。\n")

    # 9
    w("## 9. 清單\n")
    w("### 9.1 總表\n")
    w("「完成」欄可以自己把 ☐ 改成 ☑ 追蹤進度。★ 是基準圖，請最先做。\n")
    w("| # | 檔名 | 名稱 | 類別 | 優先 | 尺寸 | 生成背景 | 完成 |")
    w("|---|---|---|---|---|---|---|---|")
    n = 0
    order = [a for c in CATEGORY_ORDER for a in by_cat[c]]
    anchor_ids = set(anchors.values())
    for a in order:
        n += 1
        cat = cats[a["category"]]
        bg = BG_NAME[a["gen_bg"]].split("（")[0] if a["gen_bg"] else "不透明"
        star = " ★" if a["id"] in anchor_ids else ""
        w(f"| {n} | `{a['id']}`{star} | {a['name']} | {cat['name']} | {a['priority']} | "
          f"{cat['width']}×{cat['height']} | {bg} | ☐ |")
    w("")
    w("### 9.2 逐張規格\n")
    n = 0
    for c in CATEGORY_ORDER:
        if not by_cat[c]:
            continue
        w(f"#### {cats[c]['name']}\n")
        for a in by_cat[c]:
            n += 1
            tag = a["priority"] + ("・基準圖" if a["id"] in anchor_ids else "")
            w(f"##### {n}. `{a['id']}` — {a['name']}（{tag}）\n")
            w(f"- 用途：{a['usage']}")
            w(f"- 規格：{spec_line(m, a)}")
            w(f"- 必要特徵：{'、'.join(a['must'])}\n")
            w("生成提示詞：\n")
            w("```text")
            w(generation_prompt(m, a))
            w("```\n")
            w("檢測卡：\n")
            w("```text")
            w(check_card(m, a))
            w("```\n")
    return "\n".join(out).rstrip() + "\n"


def main():
    m = load()
    text = build(m)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"已產生 {OUT.relative_to(ROOT)}（{len(m['assets'])} 張）")


if __name__ == "__main__":
    main()
