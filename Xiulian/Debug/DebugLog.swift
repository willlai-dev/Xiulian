import Foundation
import OSLog

/// 除錯紀錄：同時寫進 OSLog 與本機檔案（保留最近 500 筆），在「除錯紀錄」頁可以一鍵複製。
///
/// 沒有 Xcode console，所以 ActivityKit、通知、背景任務、App Intent、備份、解碼的錯誤都要寫進這裡，不可以默默失敗。
/// 檔案的讀寫都在同一個序列佇列上，紀錄的順序和呼叫的順序一致。
final class DebugLog: @unchecked Sendable {
    static let shared = DebugLog()
    static let maxEntries = 500

    enum Level: String, Sendable {
        case info, warning, error

        var label: String {
            switch self {
            case .info: return "資訊"
            case .warning: return "注意"
            case .error: return "錯誤"
            }
        }
    }

    enum Category: String, Sendable {
        case app, storage, activity, intent, notification, lifespan
    }

    struct Entry: Codable, Identifiable, Hashable, Sendable {
        var id: UUID
        var date: Date
        /// 存成字串：之後新增等級時，舊的紀錄檔也讀得到。
        var level: String
        var category: String
        var message: String

        var levelValue: Level {
            Level(rawValue: level) ?? .info
        }
    }

    private let queue = DispatchQueue(label: "Xiulian.DebugLog")
    private let fileURL = AppPaths.applicationSupport?.appendingPathComponent("debug-log.json")
    private let subsystem = Bundle.main.bundleIdentifier ?? "Xiulian"
    /// 只在 `queue` 上存取。
    private var cache: [Entry]?

    private init() {}

    /// 紀錄時間一律用真實時間（不受之後測試模式的時間旅行影響）。
    func log(_ level: Level, _ category: Category, _ message: String) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        switch level {
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
        let entry = Entry(id: UUID(), date: Date(), level: level.rawValue, category: category.rawValue, message: message)
        queue.async { self.append(entry) }
    }

    /// 全部紀錄，舊的在前。
    func entries() -> [Entry] {
        queue.sync { loadIfNeeded() }
    }

    func clear() {
        queue.sync {
            cache = []
            persist([])
        }
    }

    /// 「複製全部」用的純文字，開頭附上版本、系統與時區。
    func exportText() -> String {
        let list = entries()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        var lines = [
            "修練 除錯紀錄（\(list.count) 筆，最多保留 \(Self.maxEntries) 筆）",
            "App \(AppInfo.versionDescription)｜\(AppInfo.systemDescription)｜時區 \(TimeZone.current.identifier)",
            "匯出時間 \(formatter.string(from: Date()))",
            String(repeating: "-", count: 24),
        ]
        lines += list.map { entry in
            "\(formatter.string(from: entry.date)) [\(entry.levelValue.label)] \(entry.category)｜\(entry.message)"
        }
        return lines.joined(separator: "\n")
    }

    // MARK: 以下只在 queue 上執行

    private func loadIfNeeded() -> [Entry] {
        if let cache { return cache }
        var loaded: [Entry] = []
        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
            do {
                loaded = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: fileURL))
            } catch {
                loaded = [Entry(
                    id: UUID(), date: Date(), level: Level.warning.rawValue, category: Category.storage.rawValue,
                    message: "除錯紀錄檔無法讀取，已重新開始：\(error.localizedDescription)"
                )]
            }
        }
        cache = loaded
        return loaded
    }

    private func append(_ entry: Entry) {
        var list = loadIfNeeded()
        list.append(entry)
        if list.count > Self.maxEntries {
            list.removeFirst(list.count - Self.maxEntries)
        }
        cache = list
        persist(list)
    }

    private func persist(_ list: [Entry]) {
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder().encode(list)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Logger(subsystem: subsystem, category: "debuglog")
                .error("寫入除錯紀錄失敗：\(error.localizedDescription, privacy: .public)")
        }
    }
}

/// 寫除錯紀錄的捷徑。
enum Log {
    static func info(_ category: DebugLog.Category, _ message: String) {
        DebugLog.shared.log(.info, category, message)
    }

    static func warning(_ category: DebugLog.Category, _ message: String) {
        DebugLog.shared.log(.warning, category, message)
    }

    static func error(_ category: DebugLog.Category, _ message: String, _ error: Error? = nil) {
        let text = error.map { "\(message)：\(describe($0))" } ?? message
        DebugLog.shared.log(.error, category, text)
    }

    /// 錯誤的完整描述：說明文字、domain 與 code，以及型別與 case（ActivityKit 的錯誤靠這個分辨）。
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription)（\(nsError.domain) \(nsError.code)｜\(String(reflecting: error))）"
    }
}
