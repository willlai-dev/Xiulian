import UIKit
import UserNotifications

/// app 啟動與本機通知的回呼。
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let mode = application.applicationState == .background ? "背景啟動" : "前景啟動"
        Log.info(.app, "App 啟動（\(mode)）：\(AppInfo.versionDescription)｜\(AppInfo.systemDescription)")
        return true
    }

    /// app 在前景時也顯示通知橫幅。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Log.info(.notification, "前景收到通知：\(notification.request.identifier)")
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        Log.info(.notification, "點開通知：\(response.notification.request.identifier)")
    }
}
