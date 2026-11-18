import Foundation

/// 日期歸屬（SPEC 第 1 節）：決定某個時刻算在哪一天。
///
/// 換日時間之前做的事算前一天。例如換日時間是 04:00 時，11/17 凌晨 01:30 讀書算在 11/16。
/// 全部程式都要透過這裡取得「今天」，不可以直接用午夜分日。
///
/// 判斷方式是看當地時鐘的「幾點」：早於換日時間就算前一天。
/// 一般日子等同「時間減去換日時數所在的那一天」；夏令時間切換當天，也一樣是到了換日時間才換成新的一天。
public struct DayBoundary: Sendable {
    /// 換日時間（時），已經限制在 `GameConfig.dayStartHourRange` 之內。
    public let dayStartHour: Int
    /// 一律是西曆，時區沿用建立時傳入的 calendar。
    public let calendar: Calendar

    /// - Parameters:
    ///   - dayStartHour: 換日時間（時）。超出可設定範圍時夾回範圍內。
    ///   - calendar: 只取它的時區。內部一律用西曆，手機設成佛曆或和曆也不會算錯。
    public init(dayStartHour: Int, calendar: Calendar, config: GameConfig = .standard) {
        let range = config.dayStartHourRange
        self.dayStartHour = min(max(dayStartHour, range.lowerBound), range.upperBound)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        self.calendar = gregorian
    }

    public var timeZone: TimeZone {
        calendar.timeZone
    }

    /// `date` 這個時刻屬於哪一天。
    public func day(containing date: Date) -> DayKey {
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let calendarDay = DayKey(uncheckedYear: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
        return (parts.hour ?? 0) < dayStartHour ? calendarDay.adding(days: -1) : calendarDay
    }

    /// 這一天開始的時刻，也就是當地日期的換日時間（例如 11/17 04:00）。
    public func start(of day: DayKey) -> Date {
        let parts = DateComponents(year: day.year, month: day.month, day: day.day, hour: dayStartHour)
        if let date = calendar.date(from: parts) {
            return date
        }
        // 西曆的有效日期一定換算得出來；萬一失敗，退回那一天的 UTC 午夜加上換日時數。
        return Date(timeIntervalSince1970: TimeInterval(day.serialDay * 86_400 + dayStartHour * 3_600))
    }

    /// `date` 之後的下一次換日時刻。
    public func nextRollover(after date: Date) -> Date {
        start(of: day(containing: date).adding(days: 1))
    }
}
