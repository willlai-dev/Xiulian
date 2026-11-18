import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 每日進度的 Live Activity（SPEC 5.2）。Phase 0 是技術驗證版，Phase 3 加上境界、閉關、周天等內容。
struct DailyProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyProgressAttributes.self) { context in
            DailyProgressLockScreenView(state: context.state)
                .activityBackgroundTint(XiulianPalette.ink.opacity(0.85))
                .activitySystemActionForegroundColor(XiulianPalette.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(verbatim: "今日 \(context.state.percent)%")
                        .font(.headline)
                        .foregroundStyle(DailyProgressStyle.tint(context.state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("換日倒數")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        CountdownText(end: context.state.dayEndsAt)
                            .font(.caption)
                            .frame(width: 64)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressBarWithMarker(
                            fraction: Double(context.state.percent) / 100,
                            tint: DailyProgressStyle.tint(context.state)
                        )
                        NextTaskButton(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isAchieved ? "checkmark.seal.fill" : "flame.fill")
                    .foregroundStyle(DailyProgressStyle.tint(context.state))
            } compactTrailing: {
                Text(verbatim: "\(context.state.percent)%")
                    .monospacedDigit()
                    .foregroundStyle(DailyProgressStyle.tint(context.state))
            } minimal: {
                ProgressRing(
                    fraction: Double(context.state.percent) / 100,
                    tint: DailyProgressStyle.tint(context.state)
                )
            }
            .keylineTint(DailyProgressStyle.tint(context.state))
        }
    }
}

private enum DailyProgressStyle {
    /// 達標後換成金色。
    static func tint(_ state: DailyProgressAttributes.ContentState) -> Color {
        state.isAchieved ? XiulianPalette.gold : XiulianPalette.jade
    }

    static func status(_ state: DailyProgressAttributes.ContentState) -> String {
        if state.isPerfect { return "圓滿" }
        if state.isAchieved { return "已達標" }
        return "已完成 \(state.completedCount)/\(state.totalCount)"
    }
}

private struct DailyProgressLockScreenView: View {
    let state: DailyProgressAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "今日 \(state.percent)%")
                    .font(.title2.bold())
                    .foregroundStyle(DailyProgressStyle.tint(state))
                Text(DailyProgressStyle.status(state))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("換日倒數")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    CountdownText(end: state.dayEndsAt)
                        .font(.subheadline)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }
            ProgressBarWithMarker(fraction: Double(state.percent) / 100, tint: DailyProgressStyle.tint(state))
            NextTaskButton(state: state)
        }
        .padding(16)
    }
}

/// 下一項未完成的功課與「完成」按鈕（LiveActivityIntent，在 app 的 process 執行）。
private struct NextTaskButton: View {
    let state: DailyProgressAttributes.ContentState

    var body: some View {
        if let taskID = state.nextTaskID, let name = state.nextTaskName {
            Button(intent: CompleteTaskIntent(taskID: taskID)) {
                Label("完成：\(name)", systemImage: "checkmark.circle")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .tint(DailyProgressStyle.tint(state))
        } else {
            Text("今日功課全部完成")
                .font(.subheadline)
                .foregroundStyle(XiulianPalette.gold)
        }
    }
}
