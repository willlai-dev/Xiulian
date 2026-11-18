import XCTest
@testable import XiulianCore

final class DayKeyTests: XCTestCase {
    func testParsesAndFormats() throws {
        let key = try XCTUnwrap(DayKey("2026-11-16"))
        XCTAssertEqual(key.year, 2026)
        XCTAssertEqual(key.month, 11)
        XCTAssertEqual(key.day, 16)
        XCTAssertEqual(key.description, "2026-11-16")
        XCTAssertEqual(DayKey(year: 2026, month: 1, day: 5)?.description, "2026-01-05")
        XCTAssertEqual(DayKey(year: 987, month: 6, day: 7)?.description, "0987-06-07")
    }

    func testRejectsInvalidStrings() {
        let invalid = [
            "", "2026-1-05", "2026-01-5", "26-01-05", "2026/01/05", "2026-01-05T00:00", " 2026-01-05",
            "2026-13-01", "2026-00-10", "2026-01-00", "2026-01-32", "2026-02-30", "2026-04-31",
            "2027-02-29", "+026-01-01", "-026-01-01", "２０２６-01-01", "2026-0a-01",
        ]
        for string in invalid {
            XCTAssertNil(DayKey(string), "應該不能解析：\(string)")
        }
    }

    func testRejectsInvalidComponents() {
        XCTAssertNil(DayKey(year: 2026, month: 2, day: 29))
        XCTAssertNil(DayKey(year: 2026, month: 13, day: 1))
        XCTAssertNil(DayKey(year: 2026, month: 0, day: 1))
        XCTAssertNil(DayKey(year: 2026, month: 6, day: 31))
        XCTAssertNil(DayKey(year: 2026, month: 6, day: 0))
    }

    func testLeapYears() {
        XCTAssertNotNil(DayKey("2028-02-29"))
        XCTAssertNotNil(DayKey("2000-02-29"))
        XCTAssertNil(DayKey("1900-02-29"))
        XCTAssertNil(DayKey("2100-02-29"))
    }

    func testAddingDays() throws {
        let cases: [(String, Int, String)] = [
            ("2026-11-16", 0, "2026-11-16"),
            ("2026-11-30", 1, "2026-12-01"),
            ("2026-12-31", 1, "2027-01-01"),
            ("2027-01-01", -1, "2026-12-31"),
            ("2028-02-28", 1, "2028-02-29"),
            ("2028-02-29", 1, "2028-03-01"),
            ("2027-02-28", 1, "2027-03-01"),
            ("2028-03-01", -1, "2028-02-29"),
            ("2026-11-16", 365, "2027-11-16"),
            ("2026-11-16", -400, "2025-10-12"),
        ]
        for (start, offset, expected) in cases {
            let key = try XCTUnwrap(DayKey(start))
            XCTAssertEqual(key.adding(days: offset).description, expected, "\(start) + \(offset)")
        }
    }

    func testDaysBetween() throws {
        let start = try XCTUnwrap(DayKey("2026-11-16"))
        XCTAssertEqual(start.days(to: try XCTUnwrap(DayKey("2026-12-01"))), 15)
        XCTAssertEqual(try XCTUnwrap(DayKey("2026-12-01")).days(to: start), -15)
        XCTAssertEqual(try XCTUnwrap(DayKey("2028-01-01")).days(to: try XCTUnwrap(DayKey("2029-01-01"))), 366)
        XCTAssertEqual(try XCTUnwrap(DayKey("2027-01-01")).days(to: try XCTUnwrap(DayKey("2028-01-01"))), 365)
    }

    /// 和 Foundation 的西曆逐日比對約 30 年，確認純整數換算沒有算錯。
    func testMatchesFoundationGregorianCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var date = try XCTUnwrap(calendar.date(from: DateComponents(year: 1999, month: 12, day: 1, hour: 12)))
        var key = try XCTUnwrap(DayKey("1999-12-01"))
        for _ in 0..<(366 * 30) {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard key.year == parts.year, key.month == parts.month, key.day == parts.day else {
                XCTFail("\(key) 和 Foundation 的 \(parts) 不一致")
                return
            }
            date = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))
            key = key.adding(days: 1)
        }
    }

    func testOrdering() throws {
        let keys = try ["2027-01-01", "2026-11-17", "2026-12-31", "2026-11-16"].map { try XCTUnwrap(DayKey($0)) }
        XCTAssertEqual(keys.sorted().map(\.description), ["2026-11-16", "2026-11-17", "2026-12-31", "2027-01-01"])
    }

    func testCodableAsString() throws {
        let key = try XCTUnwrap(DayKey("2026-11-16"))
        let data = try JSONEncoder().encode([key])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"["2026-11-16"]"#)
        XCTAssertEqual(try JSONDecoder().decode([DayKey].self, from: data), [key])
        XCTAssertThrowsError(try JSONDecoder().decode([DayKey].self, from: Data(#"["2026-02-30"]"#.utf8)))
    }

    func testDictionaryKeyEncodesAsObject() throws {
        let dictionary = [try XCTUnwrap(DayKey("2026-11-16")): 1]
        let data = try JSONEncoder().encode(dictionary)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"2026-11-16":1}"#)
        XCTAssertEqual(try JSONDecoder().decode([DayKey: Int].self, from: data), dictionary)
    }
}
