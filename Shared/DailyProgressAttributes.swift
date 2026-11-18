import ActivityKit
import Foundation

/// 每日進度的 Live Activity（SPEC 第 5 節）。app 與 widget 都會編譯這個檔案。
///
/// 沒有 App Groups，widget 讀不到 app 的資料：要顯示的東西全部放進 `ContentState`（合計 ≤ 4 KB）。
struct DailyProgressAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 今日日課百分比（無條件捨去）。
        var percent: Int
        var isAchieved: Bool
        var isPerfect: Bool
        var completedCount: Int
        var totalCount: Int
        /// 下一項未完成的功課；全部完成時是 nil。
        var nextTaskID: String?
        var nextTaskName: String?
        /// 下一次換日的時刻，用來倒數。
        var dayEndsAt: Date
    }

    /// 這個 activity 屬於哪一天（yyyy-MM-dd）。換日後由 app 結束它。
    var day: String
}
