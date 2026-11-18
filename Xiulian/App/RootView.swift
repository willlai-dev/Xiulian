import SwiftUI

/// Phase 0 的首頁：技術驗證版。今日頁、功課與修仙系統從 Phase 1 開始加入。
struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProbeView()
                    } label: {
                        Label("技術驗證", systemImage: "wrench.and.screwdriver")
                    }
                    NavigationLink {
                        DebugLogView()
                    } label: {
                        Label("除錯紀錄", systemImage: "doc.text.magnifyingglass")
                    }
                } footer: {
                    Text("Phase 0 技術驗證版：今日頁、功課與修仙系統從 Phase 1 開始加入。")
                }

                Section {
                    LabeledContent("歸屬日期", value: AppClock.today().description)
                    LabeledContent("版本", value: AppInfo.versionDescription)
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
