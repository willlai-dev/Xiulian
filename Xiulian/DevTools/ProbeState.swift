import Foundation
import XiulianCore

/// 技術驗證用的示範功課。不是個人資料；Phase 1 換成入門流程設定的功課。
struct DemoTask: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: TaskKind
    let isRequired: Bool
}

/// 技術驗證頁的狀態，存成 Application Support/probe.json。Phase 1 會換成正式的 AppState。
struct ProbeState: Codable, Equatable {
    /// 份量 3 + 2 + 1 + 1 = 7：依序完成時是 0% → 42% → 71%（達標）→ 85% → 100%（圓滿）。
    static let demoTasks = [
        DemoTask(id: "demo-study", name: "主題學習", kind: .study, isRequired: true),
        DemoTask(id: "demo-exercise", name: "運動 30 分鐘", kind: .exercise, isRequired: false),
        DemoTask(id: "demo-notes", name: "寫學習筆記", kind: .habit, isRequired: false),
        DemoTask(id: "demo-meditation", name: "冥想 10 分鐘", kind: .habit, isRequired: false),
    ]

    /// 示範進度屬於哪一天；換日後自動歸零。
    var progressDay: DayKey?
    /// 已完成的示範功課，依完成順序。
    var completedTaskIDs: [String] = []
    var timer: ProbeTimer?
    /// 最後一次更新的時間與來源，用來確認動態島按鈕有寫進存檔。
    var lastUpdatedAt: Date?
    var lastUpdatedBy: String?

    init() {}

    /// 寬容解碼：每個欄位都有預設值，舊的或部分損壞的存檔也讀得到。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        progressDay = try? container.decodeIfPresent(DayKey.self, forKey: .progressDay)
        completedTaskIDs = (try? container.decodeIfPresent([String].self, forKey: .completedTaskIDs)) ?? []
        timer = try? container.decodeIfPresent(ProbeTimer.self, forKey: .timer)
        lastUpdatedAt = try? container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        lastUpdatedBy = try? container.decodeIfPresent(String.self, forKey: .lastUpdatedBy)
    }

    var checkInItems: [CheckInItem] {
        Self.demoTasks.map { task in
            CheckInItem(
                id: task.id,
                kind: task.kind,
                isRequired: task.isRequired,
                isCompleted: completedTaskIDs.contains(task.id)
            )
        }
    }

    /// 由 XiulianCore 的打卡判定計算百分比、達標與圓滿。
    var evaluation: CheckInEvaluation {
        CheckInRule.evaluate(checkInItems)
    }

    var nextTask: DemoTask? {
        Self.demoTasks.first { !completedTaskIDs.contains($0.id) }
    }
}

/// 示範用的學習計時器（對應 SPEC 第 12 節的 StudyTimerState）。
struct ProbeTimer: Codable, Equatable {
    var taskName: String
    /// 這一段開始計時的時刻；暫停中是 nil。
    var runningSince: Date?
    /// 之前各段累計的秒數。
    var accumulatedSeconds: Double
    /// 暫停的時刻；計時中是 nil。
    var pausedAt: Date?

    var isPaused: Bool {
        runningSince == nil
    }

    /// 到 `now` 為止經過的秒數。
    func elapsed(at now: Date) -> TimeInterval {
        accumulatedSeconds + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// 給 `Text(timerInterval:)` 的起點：讓「現在」（暫停中是暫停的時刻）剛好顯示已經過的時間。
    func displayStart(at now: Date) -> Date {
        let reference = pausedAt ?? now
        return reference.addingTimeInterval(-elapsed(at: reference))
    }
}

extension TaskKind {
    var label: String {
        switch self {
        case .study: return "學習"
        case .exercise: return "運動"
        case .habit: return "習慣"
        }
    }
}
