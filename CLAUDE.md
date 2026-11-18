# 修練（Xiulian）— 給 Claude 的專案說明

修仙主題的「每日打卡」iOS app。目前只有我自己用，未來可能分享給朋友（每個人用自己的 Apple ID 側載）。
用免費 Apple ID 側載安裝（SideStore 或 Sideloadly），不上架 App Store。
請用**繁體中文**跟我溝通，commit 訊息和 PR 說明也用中文。

## 先讀這些文件

- `docs/SPEC.md`：功能規格（功課、打卡、提醒、動態島、學習計時器、週報、玉簡備份、壽元）
- `docs/GAME_DESIGN.md`：修仙體系（境界、屬性、掉寶、丹藥、法寶、功法），**所有數值以這份為準**
- `docs/ROADMAP.md`：開發階段（分兩批）與手機驗收清單
- `docs/ART_ASSETS.md`：美術製作規格（我拿去生圖用）。你主要看第 1 節（哪些特效由程式做）和第 8 節（導入流程）；
  佔位版本與導入的做法見下面「美術」一節

我會說「執行 Phase N」。動手前請先讀 ROADMAP 的對應段落和它引用的規格章節，
用計畫模式列出要做的事、會新增或修改的檔案，等我確認後再寫程式。

## 目標裝置

- 只有一支：**iPhone 15 Pro（有動態島），iOS 27.2**。
- Deployment target：**iOS 26.0**，不需要相容更舊的系統。

## 開發環境（最重要）

- 我用 **Windows + VS Code（Claude Code 擴充）**，**沒有 Mac**。
  這台電腦不能編譯 iOS app，沒有 Xcode，也沒有模擬器。
- 唯一的編譯方式是 GitHub Actions（`.github/workflows/build-ipa.yml`，macOS runner + Xcode）：
  先跑 `XiulianCore` 的單元測試，再用 XcodeGen 產生專案、編出未簽章的 `Xiulian.ipa`。
  合併到 main 之後會更新名為 `latest` 的 Release，我再用側載工具簽章安裝。
- 工作流程：
  1. 開新分支 → 修改 → commit → push → `gh pr create`
  2. `gh run watch` 等結果；失敗就用 `gh run view --log-failed` 讀錯誤，修好再推，直到通過
  3. 通過後，把 PR 裡的「手機測試步驟」告訴我，問我要不要合併
- 你寫的程式無法在本機驗證，所以：
  - 只用確定存在的 API；不確定時先查 Apple 官方文件，不要猜參數名稱。
  - PR 保持小而完整，避免一次改很多東西、CI 失敗時難以定位。
- 指令可能在 Git Bash 或 PowerShell 執行。`.gitattributes` 已設定 LF 換行。
- **不要修改 `.github/workflows/`**，除非我明確要求。

## 專案結構（CI 依賴這些名稱，不要改）

- 用 **XcodeGen**：`project.yml` 是唯一的專案設定來源。不提交 `.xcodeproj`（已在 `.gitignore`）。
- project、app target、scheme 都叫 `Xiulian`。scheme 必須在 `project.yml` 明確定義。
- `XiulianWidgets`：Widget extension（WidgetKit + Live Activity），embed 在 app 裡。
- `XiulianCore/`：本機 Swift Package，放所有「規則」：
  - 日期歸屬（換日 04:00）、補登、結算（依日期順序，遇到待補簽的日子就停住）
  - 身分門檻、計入份量與三分之二打卡判定、定課鎖定
  - 運動休息規則、閉關暫停、替身符（時窗與價格）、續命補簽的日期判斷
  - 日課池分配、苦修（含計時加成）、修為／境界／屬性公式
  - 走火入魔與跌落、閉關與周天、渡劫
  - 掉寶與保底、首功寶箱與今日機緣、奇遇抽選
  - 週報統計與下週小目標、通知排程的計算部分

  寫法限制：

  - 只能 `import Foundation`，不可 import SwiftUI、UIKit、ActivityKit、UserNotifications。
  - 跟時間有關的函式一律從參數接收 `now: Date` 與 `calendar: Calendar`，不可在內部呼叫 `Date()`。
  - 亂數用可注入的產生器（protocol + 可設定 seed），測試結果要能重現。
  - 數值全部放在 `GameConfig`，對應 `docs/GAME_DESIGN.md` 的表格。
  - `Package.swift` 宣告 `platforms: [.iOS(.v17), .macOS(.v14)]`。
    CI 會在 macOS 上執行 `swift test --package-path XiulianCore`，測試沒過就不會編譯 app。
  - 規則有任何變更都要附單元測試，尤其是：
    - 日期歸屬（換日 04:00）、補登、結算、定課
    - 三分之二判定（含休息日與今日該練）、身分門檻
    - 日課池分配（總和必須剛好是 100 與 30）、苦修的遞減、上限與計時加成
    - 閉關、周天、替身符時窗、運動連休天數、閉關暫停的額度與凍結
    - 走火入魔的扣除與跌落、渡劫、保底
- `Shared/`：app 與 widget **兩個 target 都要編譯**的原始碼，
  例如兩種 `ActivityAttributes`（每日進度、學習計時器）、`LiveActivityIntent`、共用的小元件。
- `Xiulian/`：app 本體（SwiftUI）。`XiulianWidgets/`：extension。
- App 與 widget target 的 `SWIFT_VERSION` 設為 `5.0`：用 Swift 6 編譯器、Swift 5 語言模式，
  減少嚴格並行檢查造成的 CI 來回。
- 名稱：App 顯示名稱「修練」；遊戲內的修仙用語用「修煉」（例如煉氣、修煉日曆）。兩種寫法都是對的，不要統一改掉。
- Bundle ID：app 是 `tw.personal.xiulian`，widget 是 `tw.personal.xiulian.widgets`。
  側載工具可能會改寫 bundle ID，所以程式裡不可寫死。
- 不使用第三方套件。

## 擴充性原則（重要）

功能分兩批實作，但設計時要替之後預留空間：

- **預留欄位與位置**：第一批就要保留第二批的資料欄位（`docs/SPEC.md` 第 12 節）和畫面位置（先顯示「即將開放」）。
- **規則資料化**：境界、物品、機緣、里程碑、成就都用 `GameConfig` 裡的表格定義；新增項目時不必改流程程式。
- **系統彼此獨立**：打卡、修為、物品、提醒、動態島、玉簡、計時器、週報各自成模組，透過明確的介面互動。
- **功能開關**：續命補簽、首功寶箱、周天、學習計時器、週報都要能關掉；之後要拔除某個功能時，不影響其他功能。
- **資料相容**：未知的物品 id 或列舉值不可讓解碼失敗，要略過並寫進除錯紀錄。
- **可以分享**：不寫死任何個人資料（道號、身分、功課、時區）；所有個人化都在入門流程與設定裡完成。
- **美術可替換**：圖片一律透過 `ArtAsset` 取得，找不到正式圖時用佔位版本（見「美術」一節）。
- **換日時間可設定**：所有「今天」的判斷都經過同一個日期歸屬函式，不可以直接用午夜分日。

## Info.plist 必要設定

App：

- `CFBundleDisplayName` = 修練
- `NSSupportsLiveActivities` = YES
- `UIFileSharingEnabled` = YES、`LSSupportsOpeningDocumentsInPlace` = YES（讓玉簡出現在「檔案」App）
- `UIBackgroundModes` = [fetch, processing]
- `BGTaskSchedulerPermittedIdentifiers` = [tw.personal.xiulian.refresh]

Widget extension：

- `NSExtension` → `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`

## 免費 Apple ID 的硬性限制（違反就裝不起來或功能失效）

- **不可使用**：
  - Push Notifications（aps-environment）
  - iCloud／CloudKit、App Groups
  - Family Controls／Screen Time API（DeviceActivity）
  - 任何需要付費會員的 capability

  原則上**不要有 `.entitlements` 檔**。
- Live Activity 一律用 `pushType: nil`。用 `.token` 在免費帳號會直接啟動失敗。
- 沒有 App Groups，widget 讀不到 app 的資料：
  - Live Activity 要顯示的內容全部放進 `ContentState`（靜態加動態資料合計 ≤ 4 KB）。
  - 不做需要讀 app 資料的主畫面小工具。
  - 動態島按鈕用 `LiveActivityIntent`。它的 `perform` 在 app 的 process 執行，由它改資料、更新 activity。
- Live Activity 最多存活 8 小時。
- 通知只用本機通知，系統最多保留 64 則待送通知。
- 每 7 天要重新簽章、覆蓋安裝，資料必須保留：
  - 狀態用 `Codable` 存成 JSON 檔，放在 Application Support。**不要用 SwiftData 或 Core Data**。
  - 解碼要寬容：新欄位一律要有預設值（`decodeIfPresent`），舊資料永遠讀得到。
  - `schemaVersion` 升級前，先自動封存一份玉簡（備份）。
  - 存檔由單一的 store（actor 或 `@MainActor`）管理，用 atomic write。
    UI 與 App Intent 可能同時存取，要避免互相覆蓋。

## 除錯（沒有 Xcode console）

- 設定 → 除錯紀錄：用 OSLog，同時寫入本機檔案（保留最近 500 筆），可一鍵複製全部內容。
- ActivityKit、通知、背景任務、App Intent、備份、解碼的錯誤都要寫進紀錄，不可默默失敗。
- 設定裡要有「開發者工具」（規格見 `docs/SPEC.md` 第 11 節）：
  - 沙盒時間旅行
  - 立即觸發通知、動態島、計時器快轉
  - 模擬替身符、跌落、壽元與續命補簽的情境
  - 列出已排程的通知

  我沒有 Xcode，這些工具就是我在手機上測試的唯一方法。

## 美術（佔位版本與正式圖）

- `art/manifest.json` 是美術清單的唯一來源：78 張圖，`id` 就是檔名，也是 app 裡的圖片名稱。
  `docs/ART_ASSETS.md` 由 `tools/build_art_doc.py` 產生，不要手改；改了 manifest 就重新產生，兩個檔案一起 commit。
- **佔位版本**：還沒有正式圖的地方，用 SwiftUI 程式畫簡單的版本，不放圖片檔。例如：
  - 立繪、師父：境界色的圓角卡片加人物剪影
  - 境界徽章：境界色的圓形，中間是境界名稱的第一個字
  - 寶箱、道具、法寶、功法、靈珠、介面道具：品質色的圓角方塊加 SF Symbols 圖示
  - 背景：黛青到墨黑的漸層；卷軸：宣紙色的圓角矩形
  - App 圖示：Phase 0 用 Pillow 產生一張 1024×1024 的簡單圖示（深色底加金色圓形）
- **`ArtAsset`**：每個 manifest id 對應一個 `ArtAsset`。畫面只透過它取圖：有正式圖就用正式圖，沒有就用佔位版本，
  畫面程式不需要知道是哪一種。
- **特效一律由程式做**（ART_ASSETS 第 1 節）：光暈、浮動、粒子、雷光等疊在圖片上，圖片本身是乾淨的靜態主體。
  開啟「減少動態效果」時改成靜態或淡入淡出。Live Activity 只用系統支援的動畫。
- **導入美術**（我說「導入美術」或列出檔名時）：
  1. 執行 `py tools/check_art.py`（或指定檔名）。不通過的不導入，把原因整理給我；只有提醒的照常導入，並轉告提醒。
  2. 用 `tools/import_art.py`（第一次導入時建立，Python + Pillow）產生 app 用的圖：
     - 依 manifest 各類別的 `display` 欄位（畫面上最大的長邊，單位是點）產生 @2x 與 @3x，都不超過原圖；轉成 8 位元 sRGB。
     - 寫進 app 的 asset catalog，圖片名稱就是 id。App 圖示寫進 AppIcon（1024×1024，移除透明通道）。
     - 有 `widget` 欄位的類別（目前只有境界徽章）另外產生小尺寸，寫進 widget extension 的 asset catalog（動態島與鎖定畫面用）。
  3. 原圖留在 `art/masters/`；不要把 `art/` 加進任何 target 的資源。
  4. `display` 是初始值。版面改變、圖顯示得比原本大時，更新 manifest 的 `display` 再重新導入。
  5. PR 的手機測試步驟要列出這次換了哪些畫面（ROADMAP「隨時：美術導入」）。
- Python：Windows 上用 `py` 執行。沒有 Python 時請我安裝（ART_ASSETS 第 8 節）；Pillow 可以直接用 `py -m pip install pillow` 安裝。

## 工作方式

1. 一次只做一個 Phase；Phase 比較大時拆成幾個 PR。
2. PR 說明包含三部分：做了什麼、手機測試步驟（對照 ROADMAP 的驗收清單）、已知限制。
3. 遇到免費帳號做不到的需求，或規格前後矛盾，先停下來問我，並提出替代方案。
4. 修改規則或數值時，同步更新 `docs/` 裡對應的文件。
