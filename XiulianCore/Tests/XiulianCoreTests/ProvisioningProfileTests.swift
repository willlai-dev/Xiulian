import XCTest
@testable import XiulianCore

final class ProvisioningProfileTests: XCTestCase {
    private let samplePlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>AppIDName</key>
        <string>Xiulian</string>
        <key>CreationDate</key>
        <date>2026-11-18T08:00:00Z</date>
        <key>ExpirationDate</key>
        <date>2026-11-25T08:00:00Z</date>
        <key>Name</key>
        <string>iOS Team Provisioning Profile: *</string>
        <key>TeamName</key>
        <string>Test Team</string>
    </dict>
    </plist>
    """

    /// 模擬 CMS 簽章：XML 前後夾著二進位資料（包含 0x00 與不是 UTF-8 的位元組）。
    private func wrapped(_ xml: String) -> Data {
        var data = Data([0x30, 0x82, 0x1F, 0x3A, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02, 0xA0, 0x00, 0xFF])
        data.append(Data(xml.utf8))
        data.append(Data([0x00, 0xA0, 0x82, 0x0F, 0xFF, 0xFE, 0x3C, 0x2F, 0x00]))
        return data
    }

    private func date(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    private func assertParseError(
        _ data: Data, _ expected: ProvisioningProfile.ParseError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(try ProvisioningProfile.parse(data), file: file, line: line) { error in
            XCTAssertEqual(error as? ProvisioningProfile.ParseError, expected, file: file, line: line)
        }
    }

    func testParsesDatesFromWrappedProfile() throws {
        let profile = try ProvisioningProfile.parse(wrapped(samplePlist))
        XCTAssertEqual(profile.expirationDate, try date("2026-11-25T08:00:00Z"))
        XCTAssertEqual(profile.creationDate, try date("2026-11-18T08:00:00Z"))
        XCTAssertEqual(profile.name, "iOS Team Provisioning Profile: *")
        XCTAssertEqual(profile.teamName, "Test Team")
    }

    func testMissingXML() {
        assertParseError(Data([0x30, 0x82, 0x00, 0x01]), .plistNotFound)
        assertParseError(Data(), .plistNotFound)
    }

    func testMissingPlistEnd() {
        let truncated = samplePlist.replacingOccurrences(of: "</plist>", with: "")
        assertParseError(wrapped(truncated), .plistNotFound)
    }

    func testCorruptedPlist() {
        let broken = #"<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>ExpirationDate</key></plist>"#
        assertParseError(wrapped(broken), .invalidPlist)
    }

    func testRootMustBeDictionary() {
        let array = #"<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><array><string>x</string></array></plist>"#
        assertParseError(wrapped(array), .invalidPlist)
    }

    func testMissingExpirationDate() {
        let noExpiration = samplePlist
            .replacingOccurrences(of: "<key>ExpirationDate</key>", with: "")
            .replacingOccurrences(of: "<date>2026-11-25T08:00:00Z</date>", with: "")
        assertParseError(wrapped(noExpiration), .missingExpirationDate)
    }

    // MARK: 壽元

    func testLifespanBreakdown() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let lifespan = Lifespan(expiration: now.addingTimeInterval(2 * 86_400 + 5 * 3_600 + 30 * 60 + 59), now: now)
        XCTAssertFalse(lifespan.isExpired)
        XCTAssertEqual(lifespan.days, 2)
        XCTAssertEqual(lifespan.hours, 5)
        XCTAssertEqual(lifespan.minutes, 30)
    }

    func testFreshSevenDayProfile() throws {
        let profile = try ProvisioningProfile.parse(wrapped(samplePlist))
        let lifespan = Lifespan(expiration: profile.expirationDate, now: try date("2026-11-18T08:00:30Z"))
        XCTAssertEqual(lifespan.days, 6)
        XCTAssertEqual(lifespan.hours, 23)
        XCTAssertEqual(lifespan.minutes, 59)
    }

    func testExpiredLifespan() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        for offset in [-10.0, 0.0] {
            let lifespan = Lifespan(expiration: now.addingTimeInterval(offset), now: now)
            XCTAssertTrue(lifespan.isExpired)
            XCTAssertEqual(lifespan.remaining, offset)
            XCTAssertEqual(lifespan.days, 0)
            XCTAssertEqual(lifespan.hours, 0)
            XCTAssertEqual(lifespan.minutes, 0)
        }
    }
}
