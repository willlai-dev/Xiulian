import XCTest
@testable import XiulianCore

final class DayBoundaryTests: XCTestCase {
    private func boundary(_ timeZone: String, hour: Int = 4) throws -> DayBoundary {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: timeZone))
        return DayBoundary(dayStartHour: hour, calendar: calendar)
    }

    /// ISO 8601 時間，例如 "2026-11-17T01:30:00+08:00"。寫明時差，夏令時間重複的那一小時也不會混淆。
    private func instant(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try XCTUnwrap(formatter.date(from: iso), "無法解析 \(iso)")
    }

    private func assertDay(
        _ boundary: DayBoundary, _ iso: String, _ expected: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        XCTAssertEqual(boundary.day(containing: try instant(iso)).description, expected, iso, file: file, line: line)
    }

    // MARK: 換日 04:00（SPEC 第 1 節）

    func testEarlyMorningBelongsToPreviousDay() throws {
        let taipei = try boundary("Asia/Taipei")
        try assertDay(taipei, "2026-11-17T00:00:00+08:00", "2026-11-16")
        try assertDay(taipei, "2026-11-17T01:30:00+08:00", "2026-11-16")
        try assertDay(taipei, "2026-11-17T03:59:59+08:00", "2026-11-16")
        try assertDay(taipei, "2026-11-17T04:00:00+08:00", "2026-11-17")
        try assertDay(taipei, "2026-11-17T12:00:00+08:00", "2026-11-17")
        try assertDay(taipei, "2026-11-17T23:59:59+08:00", "2026-11-17")
    }

    func testYearAndLeapDayBoundaries() throws {
        let taipei = try boundary("Asia/Taipei")
        try assertDay(taipei, "2027-01-01T02:00:00+08:00", "2026-12-31")
        try assertDay(taipei, "2027-01-01T04:00:00+08:00", "2027-01-01")
        try assertDay(taipei, "2028-03-01T03:00:00+08:00", "2028-02-29")
        try assertDay(taipei, "2027-03-01T03:00:00+08:00", "2027-02-28")
    }

    func testCustomDayStartHour() throws {
        let midnight = try boundary("Asia/Taipei", hour: 0)
        try assertDay(midnight, "2026-11-16T23:59:59+08:00", "2026-11-16")
        try assertDay(midnight, "2026-11-17T00:00:00+08:00", "2026-11-17")

        let six = try boundary("Asia/Taipei", hour: 6)
        try assertDay(six, "2026-11-17T05:59:59+08:00", "2026-11-16")
        try assertDay(six, "2026-11-17T06:00:00+08:00", "2026-11-17")
    }

    func testDayStartHourIsClampedToAllowedRange() throws {
        XCTAssertEqual(try boundary("Asia/Taipei", hour: 9).dayStartHour, 6)
        XCTAssertEqual(try boundary("Asia/Taipei", hour: -3).dayStartHour, 0)
        XCTAssertEqual(try boundary("Asia/Taipei", hour: 5).dayStartHour, 5)
    }

    // MARK: 夏令時間（紐約 2026-03-08 02:00 跳到 03:00；2026-11-01 02:00 退回 01:00）

    func testDaylightSavingStart() throws {
        let newYork = try boundary("America/New_York")
        try assertDay(newYork, "2026-03-08T01:30:00-05:00", "2026-03-07")
        try assertDay(newYork, "2026-03-08T03:30:00-04:00", "2026-03-07")
        try assertDay(newYork, "2026-03-08T04:00:00-04:00", "2026-03-08")
        // 只減 4 小時會得到 3/7 23:30；依當地時鐘已經過了 04:00，應該是新的一天。
        try assertDay(newYork, "2026-03-08T04:30:00-04:00", "2026-03-08")
        XCTAssertEqual(
            newYork.start(of: try XCTUnwrap(DayKey("2026-03-08"))),
            try instant("2026-03-08T04:00:00-04:00")
        )
    }

    func testDaylightSavingEnd() throws {
        let newYork = try boundary("America/New_York")
        try assertDay(newYork, "2026-11-01T01:30:00-04:00", "2026-10-31")   // 第一次的 01:30
        try assertDay(newYork, "2026-11-01T01:30:00-05:00", "2026-10-31")   // 退回後的 01:30
        try assertDay(newYork, "2026-11-01T03:59:00-05:00", "2026-10-31")
        try assertDay(newYork, "2026-11-01T04:00:00-05:00", "2026-11-01")
        XCTAssertEqual(
            newYork.start(of: try XCTUnwrap(DayKey("2026-11-01"))),
            try instant("2026-11-01T04:00:00-05:00")
        )
        XCTAssertEqual(
            newYork.nextRollover(after: try instant("2026-10-31T23:00:00-04:00")),
            try instant("2026-11-01T04:00:00-05:00")
        )
    }

    // MARK: 時區與曆法

    func testSameInstantInDifferentTimeZones() throws {
        let moment = "2026-11-16T19:30:00Z"
        try assertDay(try boundary("Asia/Taipei"), moment, "2026-11-16")       // 11/17 03:30
        try assertDay(try boundary("Asia/Tokyo"), moment, "2026-11-17")        // 11/17 04:30
        try assertDay(try boundary("America/Los_Angeles"), moment, "2026-11-16") // 11/16 11:30
    }

    func testNonGregorianCalendarStillGivesGregorianDay() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Taipei"))
        let boundary = DayBoundary(dayStartHour: 4, calendar: buddhist)
        XCTAssertEqual(boundary.calendar.identifier, .gregorian)
        try assertDay(boundary, "2026-11-17T05:00:00+08:00", "2026-11-17")
    }

    // MARK: 一天的開始與下一次換日

    func testStartOfDayAndNextRollover() throws {
        let taipei = try boundary("Asia/Taipei")
        XCTAssertEqual(taipei.start(of: try XCTUnwrap(DayKey("2026-11-17"))), try instant("2026-11-17T04:00:00+08:00"))
        XCTAssertEqual(taipei.nextRollover(after: try instant("2026-11-17T01:30:00+08:00")), try instant("2026-11-17T04:00:00+08:00"))
        XCTAssertEqual(taipei.nextRollover(after: try instant("2026-11-17T04:00:00+08:00")), try instant("2026-11-18T04:00:00+08:00"))
        XCTAssertEqual(taipei.nextRollover(after: try instant("2026-11-17T23:00:00+08:00")), try instant("2026-11-18T04:00:00+08:00"))
        XCTAssertEqual(taipei.nextRollover(after: try instant("2026-12-31T23:00:00+08:00")), try instant("2027-01-01T04:00:00+08:00"))
    }

    /// 每一天的開始時刻屬於那一天；開始前一秒屬於前一天。
    func testStartOfEveryDayRoundTrips() throws {
        for timeZone in ["Asia/Taipei", "America/New_York", "Europe/London"] {
            for hour in [0, 4, 6] {
                let boundary = try boundary(timeZone, hour: hour)
                let first = try XCTUnwrap(DayKey("2026-01-01"))
                for offset in 0..<400 {
                    let day = first.adding(days: offset)
                    let start = boundary.start(of: day)
                    guard boundary.day(containing: start) == day,
                          boundary.day(containing: start.addingTimeInterval(-1)) == day.adding(days: -1)
                    else {
                        XCTFail("\(timeZone) 換日 \(hour) 時：\(day) 的開始時刻 \(start) 不一致")
                        return
                    }
                }
            }
        }
    }
}
