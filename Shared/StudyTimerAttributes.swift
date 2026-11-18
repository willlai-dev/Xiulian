import ActivityKit
import Foundation

/// 學習計時器的 Live Activity（SPEC 6.1）。app 與 widget 都會編譯這個檔案。
///
/// 經過時間用 `Text(timerInterval:pauseTime:countsDown:)` 由系統往上數，不需要 app 更新。
struct StudyTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 計時的起點：現在減去已經過的時間（暫停中固定在暫停的時刻往前推）。
        var timerStart: Date
        /// 暫停的時刻；計時中是 nil。
        var pausedAt: Date?
        /// 單次上限的時刻（起點加 4 小時），計時會停在這裡。
        var limitEnd: Date

        var isPaused: Bool {
            pausedAt != nil
        }
    }

    /// 正在計時的功課名稱。
    var taskName: String
}
