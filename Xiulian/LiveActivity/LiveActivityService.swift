import ActivityKit
import Foundation
import XiulianCore

/// 啟動、排程、更新與結束 Live Activity。所有結果與錯誤都寫進除錯紀錄。
///
/// 免費 Apple ID 不能用推播：一律 `pushType: nil`，內容只由 app（包括在 app 的 process 執行的 App Intent）更新。
enum LiveActivityService {
    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: 每日進度

    static func dailyContent(for state: ProbeState, now: Date) -> DailyProgressAttributes.ContentState {
        let evaluation = state.evaluation
        let next = state.nextTask
        return DailyProgressAttributes.ContentState(
            percent: evaluation.percent,
            isAchieved: evaluation.isAchieved,
            isPerfect: evaluation.isPerfect,
            completedCount: state.completedTaskIDs.count,
            totalCount: ProbeState.demoTasks.count,
            nextTaskID: next?.id,
            nextTaskName: next?.name,
            dayEndsAt: AppClock.dayBoundary.nextRollover(after: now)
        )
    }

    /// 1. 立即啟動每日進度。
    static func startDailyProgress(with state: ProbeState) -> Bool {
        guard checkEnabled() else { return false }
        do {
            let activity = try Activity<DailyProgressAttributes>.request(
                attributes: DailyProgressAttributes(day: AppClock.today().description),
                content: ActivityContent(state: dailyContent(for: state, now: AppClock.now()), staleDate: nil),
                pushType: nil
            )
            Log.info(.activity, "已啟動每日進度 \(shortID(activity.id))：今日 \(state.evaluation.percent)%")
            return true
        } catch {
            Log.error(.activity, "啟動每日進度失敗", error)
            return false
        }
    }

    /// 3. 排程啟動（iOS 26 起）：到了 `start`，系統會啟動 activity，並依 alertConfiguration 亮螢幕提醒。
    /// 先結束現有的每日進度，到時候才看得出是排程啟動的那一個。
    static func scheduleDailyProgress(with state: ProbeState, at start: Date) async -> Bool {
        guard checkEnabled() else { return false }
        await end(DailyProgressAttributes.self, reason: "排程前先結束")
        do {
            // Xcode 26 SDK 的參數叫 startDate:；新版 SDK 改名為 start:，舊名標為棄用。以 CI 能編過的為準。
            let activity = try Activity<DailyProgressAttributes>.request(
                attributes: DailyProgressAttributes(day: AppClock.today().description),
                content: ActivityContent(state: dailyContent(for: state, now: start), staleDate: nil),
                pushType: nil,
                style: .standard,
                alertConfiguration: AlertConfiguration(
                    title: "【師父傳音】",
                    body: "亥時已至，今日日課尚未圓滿。（技術驗證：排程啟動）",
                    sound: .default
                ),
                startDate: start
            )
            Log.info(
                .activity,
                "已排程每日進度 \(shortID(activity.id))：\(AppFormat.time(start)) 啟動，目前狀態「\(describe(activity.activityState))」"
            )
            return true
        } catch {
            Log.error(.activity, "排程啟動失敗", error)
            return false
        }
    }

    /// 把最新進度推給進行中的每日進度（排程中的不動）。
    static func updateDailyProgress(with state: ProbeState) async {
        let content = ActivityContent(state: dailyContent(for: state, now: AppClock.now()), staleDate: nil)
        let activities = Activity<DailyProgressAttributes>.activities.filter { isRunning($0.activityState) }
        guard !activities.isEmpty else {
            Log.info(.activity, "沒有進行中的每日進度，不用更新")
            return
        }
        for activity in activities {
            await activity.update(content)
            Log.info(.activity, "已更新每日進度 \(shortID(activity.id))：今日 \(content.state.percent)%")
        }
    }

    // MARK: 學習計時器

    static func timerContent(for timer: ProbeTimer, now: Date) -> StudyTimerAttributes.ContentState {
        let start = timer.displayStart(at: now)
        let limit = TimeInterval(GameConfig.standard.maxTimerSessionHours * 3_600)
        return StudyTimerAttributes.ContentState(
            timerStart: start,
            pausedAt: timer.pausedAt,
            limitEnd: start.addingTimeInterval(limit)
        )
    }

    /// 4. 啟動計時器樣式：第二種 activity，可以和每日進度同時存在。
    static func startStudyTimer(with state: ProbeState) async -> Bool {
        guard checkEnabled() else { return false }
        guard let timer = state.timer else {
            Log.warning(.activity, "沒有計時器狀態，無法啟動計時器樣式")
            return false
        }
        await end(StudyTimerAttributes.self, reason: "重新啟動計時器")
        do {
            let activity = try Activity<StudyTimerAttributes>.request(
                attributes: StudyTimerAttributes(taskName: timer.taskName),
                content: ActivityContent(state: timerContent(for: timer, now: AppClock.now()), staleDate: nil),
                pushType: nil
            )
            Log.info(.activity, "已啟動計時器 \(shortID(activity.id))：\(timer.taskName)")
            return true
        } catch {
            Log.error(.activity, "啟動計時器失敗", error)
            return false
        }
    }

    /// 計時器狀態改變後更新；計時器已經結束時，結束對應的 activity。
    static func updateStudyTimer(with state: ProbeState) async {
        guard let timer = state.timer else {
            await end(StudyTimerAttributes.self, reason: "計時結束")
            return
        }
        let content = ActivityContent(state: timerContent(for: timer, now: AppClock.now()), staleDate: nil)
        let activities = Activity<StudyTimerAttributes>.activities.filter { isRunning($0.activityState) }
        guard !activities.isEmpty else {
            Log.info(.activity, "沒有進行中的計時器 activity，不用更新")
            return
        }
        for activity in activities {
            await activity.update(content)
            Log.info(.activity, "已更新計時器 \(shortID(activity.id))：\(timer.isPaused ? "暫停" : "計時中")")
        }
    }

    // MARK: 清單與結束

    struct Row: Identifiable {
        let id: String
        let kind: String
        let state: String
        let detail: String
    }

    /// 目前所有的 activity（包括排程中的）。
    static func rows() -> [Row] {
        let daily = Activity<DailyProgressAttributes>.activities.map { activity in
            Row(
                id: activity.id,
                kind: "每日進度",
                state: describe(activity.activityState),
                detail: "今日 \(activity.content.state.percent)%"
            )
        }
        let timers = Activity<StudyTimerAttributes>.activities.map { activity in
            Row(
                id: activity.id,
                kind: "學習計時器",
                state: describe(activity.activityState),
                detail: activity.content.state.isPaused ? "暫停中" : "計時中"
            )
        }
        return daily + timers
    }

    static func endAll() async {
        await end(DailyProgressAttributes.self, reason: "結束全部")
        await end(StudyTimerAttributes.self, reason: "結束全部")
    }

    private static func end<Attributes: ActivityAttributes>(_ type: Attributes.Type, reason: String) async {
        for activity in Activity<Attributes>.activities {
            let previous = describe(activity.activityState)
            await activity.end(nil, dismissalPolicy: .immediate)
            Log.info(.activity, "\(reason)：結束 \(shortID(activity.id))（原本「\(previous)」）")
        }
    }

    private static func checkEnabled() -> Bool {
        guard areActivitiesEnabled else {
            Log.warning(.activity, "即時動態已關閉：請到 設定 → 修練 → 即時動態 打開")
            return false
        }
        return true
    }

    /// 進行中（包括 stale）才更新內容。
    private static func isRunning(_ state: ActivityState) -> Bool {
        state == .active || state == .stale
    }

    /// 狀態的中文名稱。用字串比對，不直接引用 iOS 26 才有的 case，避免不同 SDK 之間的差異。
    static func describe(_ state: ActivityState) -> String {
        switch String(describing: state) {
        case "active": return "進行中"
        case "pending": return "排程中"
        case "stale": return "過期"
        case "ended": return "已結束"
        case "dismissed": return "已移除"
        case let other: return other
        }
    }

    private static func shortID(_ id: String) -> String {
        String(id.prefix(8))
    }
}
