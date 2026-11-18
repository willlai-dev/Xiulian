import AppIntents
import Foundation

// 動態島與鎖定畫面上的按鈕（SPEC 5.3、6.1）。
//
// LiveActivityIntent 的 perform() 由系統在 app 的 process 執行，必要時在背景啟動 app。
// 這個檔案 app 與 widget 都會編譯（widget 需要型別來建立按鈕），perform() 分別寫在：
// - Xiulian/LiveActivity/LiveActivityIntents+App.swift：真正的處理（寫存檔、寫紀錄、更新 activity）
// - XiulianWidgets/LiveActivityIntents+Widget.swift：空的實作，不會被呼叫

/// 把一項功課標成完成。
struct CompleteTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "完成一項功課"

    @Parameter(title: "功課 ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }
}

/// 學習計時器的暫停／繼續。
struct ToggleStudyTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "暫停或繼續計時"

    init() {}
}
