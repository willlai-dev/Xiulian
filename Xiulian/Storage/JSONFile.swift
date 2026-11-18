import Foundation

/// 一個 JSON 檔：讀取與 atomic write。之後的正式存檔（AppState）也用這個。
struct JSONFile<Value: Codable> {
    let url: URL

    /// 檔案不存在時回傳 nil。讀取或解碼失敗時丟出錯誤，由呼叫端寫進除錯紀錄並決定怎麼處理。
    func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONCoding.decoder().decode(Value.self, from: data)
    }

    /// 先寫到暫存檔再換掉原檔（atomic），寫到一半也不會留下壞掉的檔案。
    /// 檔案保護用「第一次解鎖後就能存取」：手機鎖定時，鎖定畫面上的動態島按鈕也要能寫檔。
    func save(_ value: Value) throws {
        let data = try JSONCoding.encoder().encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// 存檔共用的 JSON 設定：日期用 ISO 8601，方便直接打開來看。
enum JSONCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
