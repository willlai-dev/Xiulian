import Foundation

/// 修練的所有數值。
///
/// 每一個值都對應 `docs/GAME_DESIGN.md` 或 `docs/SPEC.md` 的表格；調整時兩邊一起改。
/// 規則函式一律接收 `config` 參數（預設 `.standard`），測試可以換成自訂的數值。
public struct GameConfig: Sendable {
    // MARK: 一天的定義（SPEC 第 1 節）

    /// 預設換日時間（時）：每天 04:00（寅時）。
    public var defaultDayStartHour: Int
    /// 換日時間可以設定的範圍：00:00–06:00 之間的整點。
    public var dayStartHourRange: ClosedRange<Int>

    // MARK: 功課與打卡（GAME_DESIGN 第 4 節、SPEC 第 3 節）

    /// 計分功課的份量：學習 3、運動 2、習慣 1。
    public var taskWeights: [TaskKind: Int]
    /// 打卡門檻：已完成份量 ÷ 計入份量 ≥ 2/3。
    public var checkInThreshold: Ratio
    /// 可休息的運動最多連休幾天（GAME_DESIGN 4.4）。連休達到這個天數就是「今日該練」。
    public var maxConsecutiveRestDays: Int
    /// 每天最多幾項計分功課（GAME_DESIGN 4.1）。
    public var maxScoredTasksPerDay: Int

    // MARK: 學習計時器（SPEC 6.1）

    /// 學習計時器單次最多計幾小時，超過的部分不計。
    public var maxTimerSessionHours: Int

    /// 正式使用的數值。
    public static let standard = GameConfig(
        defaultDayStartHour: 4,
        dayStartHourRange: 0...6,
        taskWeights: [.study: 3, .exercise: 2, .habit: 1],
        checkInThreshold: Ratio(numerator: 2, denominator: 3),
        maxConsecutiveRestDays: 2,
        maxScoredTasksPerDay: 8,
        maxTimerSessionHours: 4
    )

    /// 這種類型的計分功課的份量。
    public func weight(of kind: TaskKind) -> Int {
        taskWeights[kind] ?? 0
    }
}

/// 整數比例，用來做不含浮點數的門檻比較。
public struct Ratio: Hashable, Sendable {
    public var numerator: Int
    public var denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }
}
