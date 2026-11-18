# 修練 Xiulian

修仙主題的每日打卡 iOS app。以免費 Apple ID 側載安裝。

- **身分**：學生、上班族、待業、自學各有不同門檻，學習時數的計算方式也不同
- **三種計分功課**：學習（可記錄時數或用計時器）、運動（每 3 天至少 1 次，其餘可休息）、習慣；另有不計分的定時補充（丹房）
- **打卡**：必做全部完成，而且依份量計算完成三分之二，就算打卡成功；每天凌晨 04:00 換日
- **提醒**：16:00、19:00、21:00、23:00 四個檢查點，只在還沒打卡時提醒；21:00、23:00 顯示在動態島
- **修仙**：修為、境界、渡劫、屬性；走火入魔可能跌落小境界
- **連續與獎勵**：
  - 每天第一項功課開首功寶箱
  - 閉關天數（長期）與周天（7 或 14 日）兩種連續
  - 中斷時可以用替身符補救；生病或出遊可以閉關暫停（每月 5 天）
- **學習計時器**：計時中顯示在動態島，計時的時數有額外加成
- **修煉週報**：每週一整理上週紀錄，並給下週小目標
- **備份**：第 6 天自動打包玉簡（備份）並提醒重新簽章；過期的那幾天可以在重簽後補簽

## 文件

| 文件 | 內容 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | 給 Claude Code 的專案說明 |
| [docs/SPEC.md](docs/SPEC.md) | 功能規格 |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | 修仙體系與數值 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 開發階段與手機驗收清單 |
| [docs/ART_ASSETS.md](docs/ART_ASSETS.md) | 美術製作規格：78 張圖的清單、生成提示詞、檢測標準（由 `art/manifest.json` 產生） |

## 安裝到 iPhone

1. 到本 repo 的 **Releases → latest**，下載 `Xiulian.ipa`。
2. 用 SideStore（My Apps →「＋」）或 Sideloadly（拖入 .ipa）安裝，**每次都用同一個 Apple ID**。
3. 安裝時如果詢問 app extensions，選擇保留，否則動態島不會出現。
4. 每 7 天重新簽章。app 會在第 6 天提醒，並自動封存玉簡。

朋友也可以用同一個 .ipa，以自己的 Apple ID 安裝；資料各自存在自己的手機裡。

## 開發方式

- Windows + VS Code + Claude Code，本機不編譯。
- 每次 push 和 PR 都由 GitHub Actions（macOS）跑測試並編譯。
- 合併到 main 後自動更新 latest Release。
- 美術：AI 生成靜態主圖 → AI 檢測 → 放進 `art/masters/` → `py tools/check_art.py` 技術檢查 → Claude Code 導入；
  光暈、浮動、粒子等特效全部由程式製作。
