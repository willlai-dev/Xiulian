import Foundation

/// 簽章描述檔（app bundle 裡的 `embedded.mobileprovision`）的內容（SPEC 7.2）。
///
/// 描述檔是 CMS 簽章包住的 XML plist：截取 `<?xml` 到 `</plist>` 這一段，再用 `PropertyListSerialization` 解析。
public struct ProvisioningProfile: Hashable, Sendable {
    /// 簽章到期時間：過了這個時間 app 就打不開。
    public let expirationDate: Date
    public let creationDate: Date?
    public let name: String?
    public let teamName: String?

    public enum ParseError: Error, Equatable, Sendable {
        /// 找不到 `<?xml` 或 `</plist>`。
        case plistNotFound
        /// XML 無法解析成字典。
        case invalidPlist
        /// 沒有 `ExpirationDate`。
        case missingExpirationDate
    }

    public static func parse(_ data: Data) throws -> ProvisioningProfile {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else {
            throw ParseError.plistNotFound
        }

        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(
                from: data.subdata(in: start.lowerBound..<end.upperBound),
                options: [],
                format: nil
            )
        } catch {
            throw ParseError.invalidPlist
        }

        guard let dictionary = object as? [String: Any] else {
            throw ParseError.invalidPlist
        }
        guard let expirationDate = dictionary["ExpirationDate"] as? Date else {
            throw ParseError.missingExpirationDate
        }
        return ProvisioningProfile(
            expirationDate: expirationDate,
            creationDate: dictionary["CreationDate"] as? Date,
            name: dictionary["Name"] as? String,
            teamName: dictionary["TeamName"] as? String
        )
    }
}

/// 壽元：距離簽章到期還剩多久（SPEC 7.2、GAME_DESIGN 第 15 節）。
public struct Lifespan: Hashable, Sendable {
    /// 剩餘秒數；已經過期時是 0 或負數。
    public let remaining: TimeInterval
    /// 剩餘的日、時、分，無條件捨去；已經過期時都是 0。
    public let days: Int
    public let hours: Int
    public let minutes: Int

    public init(expiration: Date, now: Date) {
        remaining = expiration.timeIntervalSince(now)
        let seconds = remaining > 0 ? Int(remaining) : 0
        days = seconds / 86_400
        hours = seconds % 86_400 / 3_600
        minutes = seconds % 3_600 / 60
    }

    public var isExpired: Bool {
        remaining <= 0
    }
}
