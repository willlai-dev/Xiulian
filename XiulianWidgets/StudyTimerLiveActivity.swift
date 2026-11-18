import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 學習計時器的 Live Activity（SPEC 6.1）。經過時間由系統往上數，暫停時停住。
struct StudyTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerAttributes.self) { context in
            StudyTimerLockScreenView(taskName: context.attributes.taskName, state: context.state)
                .activityBackgroundTint(XiulianPalette.ink.opacity(0.85))
                .activitySystemActionForegroundColor(XiulianPalette.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.taskName, systemImage: "book.fill")
                        .font(.headline)
                        .foregroundStyle(XiulianPalette.gold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.title3)
                        .frame(width: 96)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimerToggleButton(isPaused: context.state.isPaused)
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .foregroundStyle(XiulianPalette.gold)
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(XiulianPalette.gold)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "book.fill")
                    .foregroundStyle(XiulianPalette.gold)
            }
            .keylineTint(XiulianPalette.gold)
        }
    }
}

private struct StudyTimerLockScreenView: View {
    let taskName: String
    let state: StudyTimerAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(taskName, systemImage: "book.fill")
                    .font(.headline)
                    .foregroundStyle(XiulianPalette.gold)
                Spacer()
                Text(state.isPaused ? "暫停中" : "計時中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ElapsedText(state: state)
                .font(.largeTitle.bold())
            TimerToggleButton(isPaused: state.isPaused)
        }
        .padding(16)
    }
}

/// 經過時間：從起點往上數；暫停時停在暫停的時刻；最多到單次上限。
private struct ElapsedText: View {
    let state: StudyTimerAttributes.ContentState

    var body: some View {
        Text(
            timerInterval: state.timerStart...max(state.timerStart, state.limitEnd),
            pauseTime: state.pausedAt,
            countsDown: false
        )
        .monospacedDigit()
    }
}

private struct TimerToggleButton: View {
    let isPaused: Bool

    var body: some View {
        let title = isPaused ? "繼續" : "暫停"
        Button(intent: ToggleStudyTimerIntent()) {
            Label(title, systemImage: isPaused ? "play.fill" : "pause.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
        }
        .tint(XiulianPalette.gold)
    }
}
