import Foundation

/// 計分功課的類型（GAME_DESIGN 4.1）。份量由 `GameConfig.taskWeights` 決定。
public enum TaskKind: String, Codable, CaseIterable, Sendable {
    /// 學習：份量 3
    case study
    /// 運動：份量 2
    case exercise
    /// 習慣：份量 1
    case habit
}

/// 運動今天的休息狀態（GAME_DESIGN 4.4）。
public enum RestStatus: String, Codable, Sendable {
    /// 不適用：學習、習慣，或「每天都要練」的運動。
    case notApplicable
    /// 可休息（已連休 0–1 天）：今天沒做就不計入份量。
    case restAllowed
    /// 今日該練（已連休 2 天以上）：計入份量，但不是必做。
    case shouldTrain

    /// 「可休息」的運動今天的狀態：已連休的天數達到上限就是今日該練。
    public static func forRestableExercise(consecutiveRestDays: Int, config: GameConfig = .standard) -> RestStatus {
        consecutiveRestDays >= config.maxConsecutiveRestDays ? .shouldTrain : .restAllowed
    }
}

/// 打卡判定的輸入：今天清單中的一項計分功課。
public struct CheckInItem: Hashable, Sendable {
    public var id: String
    public var kind: TaskKind
    public var isRequired: Bool
    public var isCompleted: Bool
    /// 只對運動有意義；其他類型一律當成 `.notApplicable`。
    public var restStatus: RestStatus

    public init(
        id: String,
        kind: TaskKind,
        isRequired: Bool = false,
        isCompleted: Bool = false,
        restStatus: RestStatus = .notApplicable
    ) {
        self.id = id
        self.kind = kind
        self.isRequired = isRequired
        self.isCompleted = isCompleted
        self.restStatus = restStatus
    }
}

/// 打卡判定的結果。
public struct CheckInEvaluation: Hashable, Sendable {
    /// 計入份量：今天全部計分功課的份量，但可休息、今天沒做的運動不計入。
    public let countedWeight: Int
    /// 已完成份量。
    public let completedWeight: Int
    /// 今日日課百分比，無條件捨去。計入份量為 0 時是 0。
    public let percent: Int
    /// 已完成份量達到三分之二（不看必做）。
    public let meetsThreshold: Bool
    /// 還沒完成的必做，依清單順序。
    public let missingRequiredIDs: [String]
    /// 達標（打卡成功）：必做全部完成，而且達到三分之二。
    public let isAchieved: Bool
    /// 圓滿：計入的功課全部完成。
    public let isPerfect: Bool
    /// 還差多少份量才到三分之二（不含必做的條件）。已經達到，或計入份量為 0 時是 0。
    public let weightNeeded: Int
    /// 今天可休息、沒做的運動（不計入份量；之後計算養息獎勵用）。
    public let restingIDs: [String]
}

/// 打卡判定（SPEC 第 3 節）。
///
/// 只做計算。「達標之後取消勾選，當天仍然維持已達標」這類狀態由每日紀錄負責。
public enum CheckInRule {
    /// 判定今天的清單。所有比較都用整數，不用浮點數。
    public static func evaluate(_ items: [CheckInItem], config: GameConfig = .standard) -> CheckInEvaluation {
        var counted = 0
        var completed = 0
        var missingRequired: [String] = []
        var resting: [String] = []

        for item in items {
            let weight = config.weight(of: item.kind)
            let rest = effectiveRestStatus(of: item)
            if item.isCompleted {
                counted += weight
                completed += weight
            } else if rest == .restAllowed {
                resting.append(item.id)
            } else {
                counted += weight
                // 可休息的運動（包括今日該練）一律不算必做。
                if item.isRequired && rest == .notApplicable {
                    missingRequired.append(item.id)
                }
            }
        }

        let threshold = config.checkInThreshold
        let meetsThreshold = counted > 0 && completed * threshold.denominator >= counted * threshold.numerator
        let minimumCompleted = counted > 0 ? ceilDiv(counted * threshold.numerator, threshold.denominator) : 0

        return CheckInEvaluation(
            countedWeight: counted,
            completedWeight: completed,
            percent: counted > 0 ? completed * 100 / counted : 0,
            meetsThreshold: meetsThreshold,
            missingRequiredIDs: missingRequired,
            isAchieved: meetsThreshold && missingRequired.isEmpty,
            isPerfect: counted > 0 && completed == counted,
            weightNeeded: max(0, minimumCompleted - completed),
            restingIDs: resting
        )
    }

    /// 還沒完成、而且「單獨完成這一項就能打卡」的項目，依清單順序（SPEC 第 3 節的介面提示）。
    /// 已經達標時是空的。
    public static func singleCompletionCandidates(_ items: [CheckInItem], config: GameConfig = .standard) -> [String] {
        guard !evaluate(items, config: config).isAchieved else { return [] }
        return items.indices.compactMap { index in
            guard !items[index].isCompleted else { return nil }
            var trial = items
            trial[index].isCompleted = true
            return evaluate(trial, config: config).isAchieved ? items[index].id : nil
        }
    }

    /// 休息規則只適用於運動。
    static func effectiveRestStatus(of item: CheckInItem) -> RestStatus {
        item.kind == .exercise ? item.restStatus : .notApplicable
    }

    private static func ceilDiv(_ value: Int, _ divisor: Int) -> Int {
        (value + divisor - 1) / divisor
    }
}
