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
            notificationSection
            lifespanSection
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
}
