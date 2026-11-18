import Foundation
import UserNotifications

/// 本機通知。Phase 0 只有權限與測試通知；檢查點與壽元警告在 Phase 3、4。
enum NotificationService {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func describe(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "尚未詢問"
        case .denied: return "已拒絕（設定 → 修練 → 通知）"
        case .authorized: return "已允許"
        case .provisional: return "暫時允許"
        case .ephemeral: return "暫時允許"
        @unknown default: return "未知（\(status.rawValue)）"
        }
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            Log.info(.notification, granted ? "通知權限：已允許" : "通知權限：沒有允許")
            return granted
        } catch {
            Log.error(.notification, "請求通知權限失敗", error)
            return false
        }
    }

    /// 排一則測試通知。沒有詢問過權限時先請求；被拒絕時寫紀錄並回傳 false。
    static func scheduleTestNotification(after seconds: TimeInterval) async -> Bool {
        switch await authorizationStatus() {
        case .notDetermined:
            guard await requestAuthorization() else { return false }
        case .denied:
            Log.warning(.notification, "通知權限已關閉，測試通知不會出現：請到 設定 → 修練 → 通知 打開")
            return false
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = "【師父傳音】"
        content.body = "這是測試通知。看得到這則，代表本機通知正常。"
        content.sound = .default

        let identifier = "probe-test-\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            Log.info(.notification, "已排程測試通知 \(identifier)（\(Int(seconds)) 秒後）")
            return true
        } catch {
            Log.error(.notification, "排程測試通知失敗", error)
            return false
        }
    }
}
