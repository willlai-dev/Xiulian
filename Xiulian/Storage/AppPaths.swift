import Foundation
import OSLog

/// app 的檔案位置。
enum AppPaths {
    /// Application Support：存檔與除錯紀錄放這裡（不會出現在「檔案」App）。第一次用到時建立。
    static let applicationSupport: URL? = {
        do {
            return try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            // 除錯紀錄本身也存在這裡，所以只能寫進 OSLog。
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Xiulian", category: "storage")
                .error("無法建立 Application Support：\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()
}
