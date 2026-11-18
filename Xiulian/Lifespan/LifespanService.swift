import Foundation
import XiulianCore

/// 壽元：讀 app bundle 裡的簽章描述檔，取得簽章到期時間（SPEC 7.2）。
enum LifespanService {
    enum ReadError: Error {
        case profileMissing
        case unreadable(String)
        case invalid(ProvisioningProfile.ParseError)

        var message: String {
            switch self {
            case .profileMissing:
                return "找不到簽章描述檔：GitHub Actions 編出的 ipa 沒有簽章，要用側載工具簽章安裝後才讀得到。"
            case .unreadable(let reason):
                return "讀不到簽章描述檔：\(reason)"
            case .invalid(let error):
                return "簽章描述檔的格式不對：\(error)"
            }
        }
    }

    static func readProfile() -> Result<ProvisioningProfile, ReadError> {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            Log.warning(.lifespan, ReadError.profileMissing.message)
            return .failure(.profileMissing)
        }
        do {
            let profile = try ProvisioningProfile.parse(Data(contentsOf: url))
            let created = profile.creationDate.map(AppFormat.dateTime) ?? "未知"
            Log.info(.lifespan, "簽章到期 \(AppFormat.dateTime(profile.expirationDate))，簽章時間 \(created)")
            return .success(profile)
        } catch let error as ProvisioningProfile.ParseError {
            let failure = ReadError.invalid(error)
            Log.error(.lifespan, failure.message)
            return .failure(failure)
        } catch {
            Log.error(.lifespan, "讀取簽章描述檔失敗", error)
            return .failure(.unreadable(error.localizedDescription))
        }
    }

    /// 例如「剩 6 日 23 時 59 分」。
    static func describe(_ lifespan: Lifespan) -> String {
        lifespan.isExpired ? "已過期" : "剩 \(lifespan.days) 日 \(lifespan.hours) 時 \(lifespan.minutes) 分"
    }
}
