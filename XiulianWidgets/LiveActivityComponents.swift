import SwiftUI

/// Live Activity 用的顏色（docs/ART_ASSETS.md 3.2 色票）。
enum XiulianPalette {
    static let ink = rgb(0x15171C)      // 墨黑
    static let paper = rgb(0xEFE8DA)    // 宣紙白
    static let gold = rgb(0xD4A84B)     // 金
    static let jade = rgb(0x5E9C8F)     // 玉青

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// 進度條，標出三分之二（打卡門檻）的位置。
struct ProgressBarWithMarker: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 6)
                Capsule()
                    .fill(tint)
                    .frame(width: width * min(max(fraction, 0), 1), height: 6)
                Rectangle()
                    .fill(XiulianPalette.paper)
                    .frame(width: 2, height: 12)
                    .offset(x: width * 2 / 3 - 1)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
    }
}

/// 環形進度（動態島的 minimal 樣式）。
struct ProgressRing: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
    }
}

/// 倒數到 `end`（例如換日）。`Text(timerInterval:)` 由系統更新，不需要 app 執行。
struct CountdownText: View {
    let end: Date

    var body: some View {
        // ClosedRange 的下限不能大於上限：已經過了 `end`（activity 還沒被結束）時顯示 0:00。
        let now = Date.now
        Text(timerInterval: min(now, end)...end, countsDown: true)
            .monospacedDigit()
    }
}
