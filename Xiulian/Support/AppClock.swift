import Foundation
import XiulianCore

/// app 內唯一的時間來源。所有「現在」與「今天」都從這裡取得；之後的測試模式（時間旅行）也從這裡接。
enum AppClock {
    static func now() -> Date {
        Date()
    }

    /// 西曆、手機目前的時區。
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// 日期歸屬。換日時間目前用預設的 04:00，Phase 1 改成讀設定。
    static var dayBoundary: DayBoundary {
        DayBoundary(dayStartHour: GameConfig.standard.defaultDayStartHour, calendar: calendar)
    }

    /// 今天（依換日時間歸屬）。
    static func today() -> DayKey {
        dayBoundary.day(containing: now())
    }
}
