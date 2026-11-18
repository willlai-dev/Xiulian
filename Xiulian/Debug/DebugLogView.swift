import SwiftUI
import UIKit

/// 設定 → 除錯紀錄：列出最近的紀錄，一鍵複製全部（貼給 Claude 用）。
struct DebugLogView: View {
    @State private var entries: [DebugLog.Entry] = []
    @State private var copiedMessage: String?
    @State private var isConfirmingClear = false

    var body: some View {
        List {
            Section {
                Button {
                    copyAll()
                } label: {
                    Label("複製全部", systemImage: "doc.on.doc")
                }
                if let copiedMessage {
                    Text(copiedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("共 \(entries.count) 筆，只保留最近 \(DebugLog.maxEntries) 筆。")
            }

            Section("紀錄（新的在上面）") {
                if entries.isEmpty {
                    Text("還沒有紀錄")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries.reversed()) { entry in
                    EntryRow(entry: entry)
                }
            }
        }
        .navigationTitle("除錯紀錄")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清除", role: .destructive) {
                    isConfirmingClear = true
                }
                .disabled(entries.isEmpty)
            }
        }
        .confirmationDialog("清除全部除錯紀錄？", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("清除", role: .destructive) {
                DebugLog.shared.clear()
                copiedMessage = nil
                reload()
            }
        }
        .onAppear(perform: reload)
        .refreshable { reload() }
    }

    private func reload() {
        entries = DebugLog.shared.entries()
    }

    private func copyAll() {
        reload()
        let text = DebugLog.shared.exportText()
        UIPasteboard.general.string = text
        copiedMessage = "已複製 \(entries.count) 筆紀錄，可以直接貼上。"
    }
}

private struct EntryRow: View {
    let entry: DebugLog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.levelValue.label)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(entry.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(AppFormat.dateTime(entry.date))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(entry.message)
                .font(.footnote)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var color: Color {
        switch entry.levelValue {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }
}
