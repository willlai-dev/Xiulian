import AppIntents

// LiveActivityIntent 由系統在 app 的 process 執行，不會呼叫 widget 這邊的 perform()。
// widget 只需要這兩個型別來建立按鈕；真正的處理在 Xiulian/LiveActivity/LiveActivityIntents+App.swift。

extension CompleteTaskIntent {
    func perform() async throws -> some IntentResult {
        .result()
    }
}

extension ToggleStudyTimerIntent {
    func perform() async throws -> some IntentResult {
        .result()
    }
}
