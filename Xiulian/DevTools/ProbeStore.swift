import Foundation
import XiulianCore

/// 技術驗證狀態的唯一 store。
///
/// 畫面與動態島按鈕（在 app 的 process 執行的 App Intent）都透過它讀寫；actor 讓兩邊不會互相覆蓋。
actor ProbeStore {
    static let shared = ProbeStore()

    enum Source: String {
        case app = "app"
        case liveActivity = "動態島按鈕"
    }

    private let file = AppPaths.applicationSupport.map {
        JSONFile<ProbeState>(url: $0.appendingPathComponent("probe.json"))
    }
    private var cache: ProbeState?

    /// 目前的狀態；換日後示範進度自動歸零。
    func current() -> ProbeState {
        var state = loaded()
        if rollOverIfNeeded(&state) {
            save(state)
        }
        return state
    }

    // MARK: 示範功課

    func completeTask(id: String, source: Source) -> ProbeState {
        var state = loaded()
        rollOverIfNeeded(&state)
        if state.completedTaskIDs.contains(id) {
            Log.warning(.storage, "示範功課 \(id) 已經完成過（來源：\(source.rawValue)）")
        } else if let task = ProbeState.demoTasks.first(where: { $0.id == id }) {
            state.completedTaskIDs.append(id)
            Log.info(.storage, "完成「\(task.name)」（來源：\(source.rawValue)），今日 \(state.evaluation.percent)%")
        } else {
            Log.warning(.storage, "找不到示範功課 \(id)（來源：\(source.rawValue)）")
        }
        return commit(state, source: source)
    }

    func completeNextTask(source: Source) -> ProbeState {
        let state = current()
        guard let next = state.nextTask else {
            Log.info(.storage, "示範功課已經全部完成")
            return state
        }
        return completeTask(id: next.id, source: source)
    }

    func resetProgress() -> ProbeState {
        var state = loaded()
        state.progressDay = AppClock.today()
        state.completedTaskIDs = []
        Log.info(.storage, "重設示範進度")
        return commit(state, source: .app)
    }

    // MARK: 示範計時器

    func startTimer(taskName: String) -> ProbeState {
        var state = loaded()
        state.timer = ProbeTimer(taskName: taskName, runningSince: AppClock.now(), accumulatedSeconds: 0, pausedAt: nil)
        Log.info(.storage, "開始計時「\(taskName)」")
        return commit(state, source: .app)
    }

    func toggleTimerPause(source: Source) -> ProbeState {
        var state = loaded()
        guard var timer = state.timer else {
            Log.warning(.storage, "沒有進行中的計時器，無法暫停或繼續（來源：\(source.rawValue)）")
            return state
        }
        let now = AppClock.now()
        if let runningSince = timer.runningSince {
            timer.accumulatedSeconds += max(0, now.timeIntervalSince(runningSince))
            timer.runningSince = nil
            timer.pausedAt = now
            Log.info(.storage, "計時器暫停（來源：\(source.rawValue)），已累計 \(Int(timer.accumulatedSeconds)) 秒")
        } else {
            timer.runningSince = now
            timer.pausedAt = nil
            Log.info(.storage, "計時器繼續（來源：\(source.rawValue)）")
        }
        state.timer = timer
        return commit(state, source: source)
    }

    func stopTimer() -> ProbeState {
        var state = loaded()
        if let timer = state.timer {
            Log.info(.storage, "結束計時，共 \(Int(timer.elapsed(at: AppClock.now()))) 秒")
        }
        state.timer = nil
        return commit(state, source: .app)
    }

    // MARK: 存檔

    private func loaded() -> ProbeState {
        if let cache { return cache }
        var state = ProbeState()
        if let file {
            do {
                state = try file.load() ?? ProbeState()
            } catch {
                Log.error(.storage, "probe.json 解碼失敗，改用預設值", error)
            }
        } else {
            Log.error(.storage, "找不到 Application Support，示範狀態不會存檔")
        }
        cache = state
        return state
    }

    /// 換日時把示範進度歸零。有變動時回傳 true。
    @discardableResult
    private func rollOverIfNeeded(_ state: inout ProbeState) -> Bool {
        let today = AppClock.today()
        guard state.progressDay != today else { return false }
        if let previous = state.progressDay {
            Log.info(.storage, "換日（\(previous) → \(today)），示範進度歸零")
        }
        state.progressDay = today
        state.completedTaskIDs = []
        return true
    }

    private func commit(_ state: ProbeState, source: Source) -> ProbeState {
        var state = state
        state.lastUpdatedAt = AppClock.now()
        state.lastUpdatedBy = source.rawValue
        save(state)
        return state
    }

    private func save(_ state: ProbeState) {
        cache = state
        guard let file else { return }
        do {
            try file.save(state)
        } catch {
            Log.error(.storage, "probe.json 寫入失敗", error)
        }
    }
}
