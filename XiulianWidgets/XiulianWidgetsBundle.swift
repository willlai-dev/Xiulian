import SwiftUI
import WidgetKit

/// Widget extension 只放 Live Activity。沒有 App Groups 讀不到 app 的資料，所以不做主畫面小工具。
@main
struct XiulianWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyProgressLiveActivity()
    }
}
