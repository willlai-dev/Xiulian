import ActivityKit
import SwiftUI
import WidgetKit

/// 每日進度的 Live Activity。版面與按鈕在技術驗證的第三步補上。
struct DailyProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyProgressAttributes.self) { context in
            Text(verbatim: "今日 \(context.state.percent)%")
                .font(.title2.bold())
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: "今日 \(context.state.percent)%")
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
            } compactTrailing: {
                Text(verbatim: "\(context.state.percent)%")
            } minimal: {
                Text(verbatim: "\(context.state.percent)")
            }
        }
    }
}
