import Foundation

/// 遊戲裡的「一天」：西曆的年、月、日，不含時間與時區。
///
/// 某個時刻屬於哪一天，一律由 `DayBoundary` 依換日時間決定，不可以直接用午夜分日。
/// 編碼成 `"yyyy-MM-dd"` 字串；當字典的 key 時也編碼成 JSON 物件的 key。
public struct DayKey: Hashable, Comparable, Sendable, LosslessStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// 日期不存在（例如 2 月 30 日、平年的 2 月 29 日）時回傳 nil。
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let normalized = DayKey.civil(fromSerialDay: DayKey.serialDay(year: year, month: month, day: day))
        guard normalized.year == year, normalized.month == month, normalized.day == day else { return nil }
        self.init(uncheckedYear: year, month: month, day: day)
    }

    /// 解析 `"yyyy-MM-dd"`。格式不對或日期不存在時回傳 nil。
    public init?(_ description: String) {
        let parts = description.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// 已知是正確日期時使用（例如由西曆換算出來的結果）。
    init(uncheckedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// `"yyyy-MM-dd"`
    public var description: String {
        "\(DayKey.zeroPadded(year, width: 4))-\(DayKey.zeroPadded(month, width: 2))-\(DayKey.zeroPadded(day, width: 2))"
    }

    private static func zeroPadded(_ value: Int, width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    /// 往後（正數）或往前（負數）幾天。
    public func adding(days: Int) -> DayKey {
        let date = DayKey.civil(fromSerialDay: serialDay + days)
        return DayKey(uncheckedYear: date.year, month: date.month, day: date.day)
    }

    /// 從這一天到 `other` 相差幾天；`other` 比較晚時是正數。
    public func days(to other: DayKey) -> Int {
        other.serialDay - serialDay
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: 西曆換算（1970-01-01 是第 0 天）
    // 純整數運算，不依賴 Calendar。演算法：Howard Hinnant, "chrono-Compatible Low-Level Date Algorithms"。

    var serialDay: Int {
        DayKey.serialDay(year: year, month: month, day: day)
    }

    static func serialDay(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400                                   // [0, 399]
        let shiftedMonth = (month + 9) % 12                             // 三月是 0，二月是 11
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1          // [0, 365]
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    static func civil(fromSerialDay serial: Int) -> (year: Int, month: Int, day: Int) {
        let z = serial + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097                                // [0, 146096]
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153                    // [0, 11]
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1          // [1, 31]
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}

extension DayKey: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let key = DayKey(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "不是有效的日期：\(string)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension DayKey: CodingKeyRepresentable {
    public var codingKey: CodingKey {
        DayCodingKey(stringValue: description)
    }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(codingKey.stringValue)
    }
}

private struct DayCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}
