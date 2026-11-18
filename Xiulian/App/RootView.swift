import SwiftUI

/// Phase 0 的首頁：技術驗證版。今日頁、功課與修仙系統從 Phase 1 開始加入。
struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("歸屬日期", value: AppClock.today().description)
                } header: {
                    Text("今天")
                } footer: {
                    Text("換日時間 \(AppClock.dayBoundary.dayStartHour):00，之前做的事算前一天。")
                }
            }
            .navigationTitle("修練")
        }
    }
}
