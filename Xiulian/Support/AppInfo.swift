import Foundation

/// 版本與裝置資訊（除錯紀錄的開頭、技術驗證頁會用到）。
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    /// 例如「0.1.0 (1)」。
    static var versionDescription: String {
        "\(version) (\(build))"
    }

    /// 例如「iPhone16,1｜iOS 27.2.0」。
    static var systemDescription: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(deviceModel)｜iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

/// 畫面與紀錄用的時間格式（手機目前的時區）。
enum AppFormat {
    /// 例如「2026-11-19 21:00:00」。
    static func dateTime(_ date: Date) -> String {
        string(from: date, format: "yyyy-MM-dd HH:mm:ss")
    }

    /// 例如「21:00:00」。
    static func time(_ date: Date) -> String {
        string(from: date, format: "HH:mm:ss")
    }

    private static func string(from date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
