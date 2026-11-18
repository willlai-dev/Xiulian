import AppIntents
import Foundation

// 動態島按鈕的真正處理。系統在 app 的 process 執行（必要時在背景啟動 app）：
// 寫除錯紀錄 → 寫存檔 → 更新進行中的 activity。

extension CompleteTaskIntent {
    func perform() async throws -> some IntentResult {
        Log.info(.intent, "動態島按鈕：完成 \(taskID)")
        let state = await ProbeStore.shared.completeTask(id: taskID, source: .liveActivity)
        await LiveActivityService.updateDailyProgress(with: state)
        return .result()
    }
}

extension ToggleStudyTimerIntent {
    func perform() async throws -> some IntentResult {
        Log.info(.intent, "動態島按鈕：暫停／繼續計時")
        let state = await ProbeStore.shared.toggleTimerPause(source: .liveActivity)
        await LiveActivityService.updateStudyTimer(with: state)
        return .result()
    }
}
