import Foundation
import Observation
import XiulianCore

/// 技術驗證頁的狀態與動作。每個動作的結果都寫進除錯紀錄。
@MainActor
@Observable
final class ProbeModel {
    var state = ProbeState()
    var notificationStatus = "讀取中…"
    var activitiesEnabled = false
    var activityRows: [LiveActivityService.Row] = []
    var scheduledStart: Date?
    var lifespanLines: [String] = []
    /// 最近一次操作的結果，顯示在頁面底部。
    var lastAction: String?

    func refresh() async {
        state = await ProbeStore.shared.current()
        notificationStatus = NotificationService.describe(await NotificationService.authorizationStatus())
        activitiesEnabled = LiveActivityService.areActivitiesEnabled
        activityRows = LiveActivityService.rows()
    }

    // MARK: 示範進度

    func completeNextInApp() async {
        state = await ProbeStore.shared.completeNextTask(source: .app)
        await LiveActivityService.updateDailyProgress(with: state)
        lastAction = "在 app 內完成一項：今日 \(state.evaluation.percent)%"
        await refresh()
    }

    func resetDemo() async {
        state = await ProbeStore.shared.resetProgress()
        await LiveActivityService.updateDailyProgress(with: state)
        lastAction = "已重設示範進度"
        await refresh()
    }

    // MARK: 1. 動態島（每日進度）

    func startDailyProgress() async {
        state = await ProbeStore.shared.current()
        lastAction = LiveActivityService.startDailyProgress(with: state)
            ? "已啟動：回到主畫面看動態島，或鎖定螢幕看鎖定畫面。"
            : "啟動失敗，請看除錯紀錄。"
        await refresh()
    }

    // MARK: 3. 排程啟動

    func scheduleDailyProgress() async {
        state = await ProbeStore.shared.current()
        let start = AppClock.now().addingTimeInterval(120)
        if await LiveActivityService.scheduleDailyProgress(with: state, at: start) {
            scheduledStart = start
            lastAction = "已排程：\(AppFormat.time(start)) 自動出現。現在可以鎖定螢幕等待。"
        } else {
            scheduledStart = nil
            lastAction = "排程失敗，請看除錯紀錄。"
        }
        await refresh()
    }

    // MARK: 4. 計時器樣式

    func startTimer() async {
        state = await ProbeStore.shared.startTimer(taskName: "主題學習")
        let started = await LiveActivityService.startStudyTimer(with: state)
        lastAction = started
            ? "已啟動計時器：和每日進度同時存在時，動態島左右各顯示一個。"
            : "啟動計時器失敗，請看除錯紀錄。"
        await refresh()
    }

    func toggleTimer() async {
        state = await ProbeStore.shared.toggleTimerPause(source: .app)
        await LiveActivityService.updateStudyTimer(with: state)
        lastAction = state.timer?.isPaused == true ? "計時器已暫停" : "計時器繼續計時"
        await refresh()
    }

    func stopTimer() async {
        state = await ProbeStore.shared.stopTimer()
        await LiveActivityService.updateStudyTimer(with: state)
        lastAction = "已結束計時器"
        await refresh()
    }

    // MARK: 目前的動態島

    func endAllActivities() async {
        await LiveActivityService.endAll()
        scheduledStart = nil
        lastAction = "已結束全部動態島"
        await refresh()
    }

    // MARK: 5. 通知

    func requestNotificationPermission() async {
        let granted = await NotificationService.requestAuthorization()
        lastAction = granted ? "通知權限：已允許" : "通知權限：沒有允許"
        await refresh()
    }

    func scheduleTestNotification() async {
        let scheduled = await NotificationService.scheduleTestNotification(after: 10)
        lastAction = scheduled
            ? "已排程：10 秒後送出測試通知，可以先回主畫面或鎖定螢幕。"
            : "沒有排程成功，請看除錯紀錄。"
        await refresh()
    }

    // MARK: 6. 壽元

    func showLifespan() {
        switch LifespanService.readProfile() {
        case .success(let profile):
            let lifespan = Lifespan(expiration: profile.expirationDate, now: AppClock.now())
            lifespanLines = [
                "到期：\(AppFormat.dateTime(profile.expirationDate))",
                "壽元：\(LifespanService.describe(lifespan))",
                "簽章時間：\(profile.creationDate.map(AppFormat.dateTime) ?? "未知")",
            ]
            lastAction = "已讀取壽元：\(LifespanService.describe(lifespan))"
        case .failure(let error):
            lifespanLines = ["壽元：未知", error.message]
            lastAction = "讀不到壽元"
        }
    }
}
