import Foundation
import Observation
import XiulianCore

/// 技術驗證頁的狀態與動作。每個動作的結果都寫進除錯紀錄。
@MainActor
@Observable
final class ProbeModel {
    var state = ProbeState()
    var notificationStatus = "讀取中…"
    var lifespanLines: [String] = []
    /// 最近一次操作的結果，顯示在頁面底部。
    var lastAction: String?

    func refresh() async {
        state = await ProbeStore.shared.current()
        notificationStatus = NotificationService.describe(await NotificationService.authorizationStatus())
    }

    // MARK: 示範進度

    func completeNextInApp() async {
        state = await ProbeStore.shared.completeNextTask(source: .app)
        lastAction = "在 app 內完成一項：今日 \(state.evaluation.percent)%"
    }

    func resetDemo() async {
        state = await ProbeStore.shared.resetProgress()
        lastAction = "已重設示範進度"
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
