import SwiftUI
import XiulianCore

/// 技術驗證頁（之後變成開發者工具）。按鈕編號對應 docs/ROADMAP.md Phase 0 的驗收清單。
struct ProbeView: View {
    @State private var model = ProbeModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            statusSection
            demoSection
            dailyProgressSection
            scheduleSection
            timerSection
            notificationSection
            lifespanSection
            activityListSection
            if let lastAction = model.lastAction {
                Section("最近一次操作") {
                    Text(lastAction)
                }
            }
        }
        .navigationTitle("技術驗證")
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }

    // MARK: 狀態

    private var statusSection: some View {
        Section("狀態") {
            LabeledContent("版本", value: AppInfo.versionDescription)
            LabeledContent("今天（換日 \(AppClock.dayBoundary.dayStartHour):00）", value: AppClock.today().description)
            LabeledContent("下次換日", value: AppFormat.dateTime(AppClock.dayBoundary.nextRollover(after: AppClock.now())))
            LabeledContent("即時動態", value: model.activitiesEnabled ? "已開啟" : "已關閉（設定 → 修練）")
            LabeledContent("通知權限", value: model.notificationStatus)
        }
    }

    // MARK: 示範進度與存檔

    private var demoSection: some View {
        Section {
            ForEach(ProbeState.demoTasks) { task in
                HStack {
                    Image(systemName: model.state.completedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.state.completedTaskIDs.contains(task.id) ? .green : .secondary)
                    Text(task.name)
                    if task.isRequired {
                        Text("必做")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(task.kind.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("今日日課", value: progressText)
            LabeledContent("存檔最後更新", value: lastUpdatedText)
            Button("在 app 內完成一項") {
                Task { await model.completeNextInApp() }
            }
            .disabled(model.state.nextTask == nil)
            Button("重設示範進度", role: .destructive) {
                Task { await model.resetDemo() }
            }
        } header: {
            Text("示範進度與存檔")
        } footer: {
            Text("動態島上的按鈕會寫進同一個存檔；回到這頁時，「存檔最後更新」的來源會顯示「動態島按鈕」。")
        }
    }

    private var progressText: String {
        let evaluation = model.state.evaluation
        let status = evaluation.isPerfect ? "圓滿" : evaluation.isAchieved ? "已達標" : "未達標"
        return "\(evaluation.percent)%（\(status)）"
    }

    private var lastUpdatedText: String {
        guard let updatedAt = model.state.lastUpdatedAt else { return "尚無" }
        return "\(AppFormat.time(updatedAt))（\(model.state.lastUpdatedBy ?? "?")）"
    }

    // MARK: 1–2. 動態島（每日進度）

    private var dailyProgressSection: some View {
        Section {
            Button("1. 啟動動態島") {
                Task { await model.startDailyProgress() }
            }
        } header: {
            Text("1–2. 動態島（每日進度）")
        } footer: {
            Text("啟動後回到主畫面：動態島顯示百分比，鎖定畫面也看得到。長按動態島展開，按「完成」→ 百分比增加，並寫進存檔與除錯紀錄。")
        }
    }

    // MARK: 3. 排程啟動

    private var scheduleSection: some View {
        Section {
            Button("3. 2 分鐘後自動出現") {
                Task { await model.scheduleDailyProgress() }
            }
            if let start = model.scheduledStart {
                LabeledContent("預定出現", value: AppFormat.time(start))
            }
        } header: {
            Text("3. 排程啟動")
        } footer: {
            Text("會先結束目前的每日進度。按下後鎖定螢幕，2 分鐘後動態島應該自動出現，並亮螢幕顯示師父傳音。")
        }
    }

    // MARK: 4. 計時器樣式

    private var timerSection: some View {
        Section {
            Button("4. 啟動計時器樣式") {
                Task { await model.startTimer() }
            }
            if let timer = model.state.timer {
                LabeledContent("經過時間") {
                    ProbeTimerText(timer: timer)
                }
                Button(timer.isPaused ? "繼續" : "暫停") {
                    Task { await model.toggleTimer() }
                }
                Button("結束計時器", role: .destructive) {
                    Task { await model.stopTimer() }
                }
            }
        } header: {
            Text("4. 計時器樣式")
        } footer: {
            Text("計時器是第二種動態島，可以和每日進度同時存在。時間由系統自己跑；按暫停會停住。")
        }
    }

    // MARK: 5. 通知

    private var notificationSection: some View {
        Section {
            Button("請求通知權限") {
                Task { await model.requestNotificationPermission() }
            }
            Button("5. 10 秒後測試通知") {
                Task { await model.scheduleTestNotification() }
            }
        } header: {
            Text("5. 通知")
        } footer: {
            Text("按下後可以回主畫面或鎖定螢幕；app 在前景時也會顯示橫幅。")
        }
    }

    // MARK: 6. 壽元

    private var lifespanSection: some View {
        Section {
            Button("6. 顯示壽元") {
                model.showLifespan()
            }
            ForEach(model.lifespanLines, id: \.self) { line in
                Text(line)
            }
        } header: {
            Text("6. 壽元")
        } footer: {
            Text("讀取 app 裡的簽章描述檔（embedded.mobileprovision）的到期時間；剛簽章時大約剩 7 天。")
        }
    }

    // MARK: 目前的動態島

    private var activityListSection: some View {
        Section {
            if model.activityRows.isEmpty {
                Text("目前沒有")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.activityRows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(row.kind)・\(row.state)")
                    Text(verbatim: "\(row.detail)｜\(row.id.prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("重新整理") {
                Task { await model.refresh() }
            }
            Button("結束全部動態島", role: .destructive) {
                Task { await model.endAllActivities() }
            }
        } header: {
            Text("目前的動態島")
        } footer: {
            Text("包括排程中、還沒出現的。")
        }
    }
}

/// app 內的計時器顯示，和動態島用同一種算法。
private struct ProbeTimerText: View {
    let timer: ProbeTimer

    var body: some View {
        let content = LiveActivityService.timerContent(for: timer, now: AppClock.now())
        Text(
            timerInterval: content.timerStart...max(content.timerStart, content.limitEnd),
            pauseTime: content.pausedAt,
            countsDown: false
        )
        .monospacedDigit()
    }
}
