import XCTest
@testable import XiulianCore

final class CheckInRuleTests: XCTestCase {
    // MARK: 小工具

    private func study(_ id: String, done: Bool = false, required: Bool = false) -> CheckInItem {
        CheckInItem(id: id, kind: .study, isRequired: required, isCompleted: done)
    }

    private func exercise(_ id: String, done: Bool = false, required: Bool = false, rest: RestStatus = .notApplicable) -> CheckInItem {
        CheckInItem(id: id, kind: .exercise, isRequired: required, isCompleted: done, restStatus: rest)
    }

    private func habit(_ id: String, done: Bool = false, required: Bool = false) -> CheckInItem {
        CheckInItem(id: id, kind: .habit, isRequired: required, isCompleted: done)
    }

    // MARK: SPEC 第 3 節的範例表（整張）

    func testSpecExampleTable() {
        struct Row {
            let name: String
            let items: [CheckInItem]
            let counted: Int
            let completed: Int
            let percent: Int
            let achieved: Bool
        }

        let rows = [
            Row(name: "學習、運動（每天練）、習慣：漏習慣",
                items: [study("s", done: true), exercise("e", done: true), habit("h")],
                counted: 6, completed: 5, percent: 83, achieved: true),
            Row(name: "學習、運動（每天練）、習慣：漏運動（剛好三分之二）",
                items: [study("s", done: true), exercise("e"), habit("h", done: true)],
                counted: 6, completed: 4, percent: 66, achieved: true),
            Row(name: "學習、運動（每天練）、習慣：漏學習",
                items: [study("s"), exercise("e", done: true), habit("h", done: true)],
                counted: 6, completed: 3, percent: 50, achieved: false),
            Row(name: "學習、學習、運動（每天練）、習慣：漏一項學習",
                items: [study("s1", done: true), study("s2"), exercise("e", done: true), habit("h", done: true)],
                counted: 9, completed: 6, percent: 66, achieved: true),
            Row(name: "學習、運動（每天練）、習慣 ×3：漏學習（多加小項目也沒用）",
                items: [study("s"), exercise("e", done: true), habit("h1", done: true), habit("h2", done: true), habit("h3", done: true)],
                counted: 8, completed: 5, percent: 62, achieved: false),
            Row(name: "學習、運動（可休息）、習慣：休息日，只做學習",
                items: [study("s", done: true), exercise("e", rest: .restAllowed), habit("h")],
                counted: 4, completed: 3, percent: 75, achieved: true),
            Row(name: "學習、運動（可休息）、習慣：今日該練，沒運動，其他都做",
                items: [study("s", done: true), exercise("e", rest: .shouldTrain), habit("h", done: true)],
                counted: 6, completed: 4, percent: 66, achieved: true),
            Row(name: "學習、運動（可休息）、習慣：今日該練，只做學習",
                items: [study("s", done: true), exercise("e", rest: .shouldTrain), habit("h")],
                counted: 6, completed: 3, percent: 50, achieved: false),
        ]

        for row in rows {
            let result = CheckInRule.evaluate(row.items)
            XCTAssertEqual(result.countedWeight, row.counted, "計入份量：\(row.name)")
            XCTAssertEqual(result.completedWeight, row.completed, "已完成份量：\(row.name)")
            XCTAssertEqual(result.percent, row.percent, "百分比：\(row.name)")
            XCTAssertEqual(result.isAchieved, row.achieved, "達標：\(row.name)")
        }
    }

    func testRestDayExerciseIsListedAsResting() {
        let result = CheckInRule.evaluate([study("s", done: true), exercise("e", rest: .restAllowed), habit("h")])
        XCTAssertEqual(result.restingIDs, ["e"])
    }

    // MARK: 必做

    func testMissingRequiredBlocksCheckInEvenAboveTwoThirds() {
        let result = CheckInRule.evaluate([study("s", done: true), exercise("e", done: true), habit("h", required: true)])
        XCTAssertEqual(result.percent, 83)
        XCTAssertTrue(result.meetsThreshold)
        XCTAssertEqual(result.missingRequiredIDs, ["h"])
        XCTAssertFalse(result.isAchieved)
    }

    func testCompletedRequiredDoesNotBlock() {
        let result = CheckInRule.evaluate([study("s", done: true, required: true), exercise("e", done: true), habit("h")])
        XCTAssertEqual(result.missingRequiredIDs, [])
        XCTAssertTrue(result.isAchieved)
    }

    func testDailyExerciseCanBeRequired() {
        let result = CheckInRule.evaluate([study("s", done: true), exercise("e", required: true), habit("h", done: true)])
        XCTAssertTrue(result.meetsThreshold)
        XCTAssertEqual(result.missingRequiredIDs, ["e"])
        XCTAssertFalse(result.isAchieved)
    }

    func testRestableExerciseIsNeverRequired() {
        for rest in [RestStatus.restAllowed, .shouldTrain] {
            let result = CheckInRule.evaluate([study("s", done: true), exercise("e", required: true, rest: rest), habit("h", done: true)])
            XCTAssertEqual(result.missingRequiredIDs, [], "\(rest)")
            XCTAssertTrue(result.isAchieved, "\(rest)")
        }
    }

    // MARK: 休息規則

    func testRestDayExerciseCountsOnceDone() {
        let result = CheckInRule.evaluate([study("s"), exercise("e", done: true, rest: .restAllowed), habit("h", done: true)])
        XCTAssertEqual(result.countedWeight, 6)
        XCTAssertEqual(result.completedWeight, 3)
        XCTAssertEqual(result.restingIDs, [])
        XCTAssertFalse(result.isAchieved)
    }

    func testRestStatusOnlyAppliesToExercise() {
        let item = CheckInItem(id: "h", kind: .habit, restStatus: .restAllowed)
        let result = CheckInRule.evaluate([study("s", done: true), item])
        XCTAssertEqual(result.countedWeight, 4)
        XCTAssertEqual(result.restingIDs, [])
    }

    func testRestStatusFromConsecutiveRestDays() {
        XCTAssertEqual(RestStatus.forRestableExercise(consecutiveRestDays: 0), .restAllowed)
        XCTAssertEqual(RestStatus.forRestableExercise(consecutiveRestDays: 1), .restAllowed)
        XCTAssertEqual(RestStatus.forRestableExercise(consecutiveRestDays: 2), .shouldTrain)
        XCTAssertEqual(RestStatus.forRestableExercise(consecutiveRestDays: 5), .shouldTrain)

        var config = GameConfig.standard
        config.maxConsecutiveRestDays = 3
        XCTAssertEqual(RestStatus.forRestableExercise(consecutiveRestDays: 2, config: config), .restAllowed)
        XCTAssertEqual(RestStatus.forRestableExercise(consecutiveRestDays: 3, config: config), .shouldTrain)
    }

    // MARK: 圓滿與邊界

    func testPerfect() {
        let all = CheckInRule.evaluate([study("s", done: true), exercise("e", done: true), habit("h", done: true)])
        XCTAssertEqual(all.percent, 100)
        XCTAssertTrue(all.isPerfect)
        XCTAssertTrue(all.isAchieved)

        let restDay = CheckInRule.evaluate([study("s", done: true), exercise("e", rest: .restAllowed), habit("h", done: true)])
        XCTAssertEqual(restDay.countedWeight, 4)
        XCTAssertTrue(restDay.isPerfect, "休息日沒做的運動不計入，其餘全部完成就是圓滿")

        let missingOne = CheckInRule.evaluate([study("s", done: true), exercise("e", done: true), habit("h")])
        XCTAssertFalse(missingOne.isPerfect)
    }

    func testZeroCountedWeightIsNotAchieved() {
        let lists: [[CheckInItem]] = [[], [exercise("e", rest: .restAllowed)]]
        for items in lists {
            let result = CheckInRule.evaluate(items)
            XCTAssertEqual(result.countedWeight, 0)
            XCTAssertEqual(result.percent, 0)
            XCTAssertFalse(result.meetsThreshold)
            XCTAssertFalse(result.isAchieved)
            XCTAssertFalse(result.isPerfect)
            XCTAssertEqual(result.weightNeeded, 0)
        }
    }

    /// 計入份量最多 24（8 項 × 3）：畫面顯示 66% 時一定剛好達到三分之二，65% 以下一定沒達到。
    func testFlooredPercentNeverMisleads() {
        for counted in 1...24 {
            for completed in 0...counted {
                let items = (0..<counted).map { CheckInItem(id: "h\($0)", kind: .habit, isCompleted: $0 < completed) }
                let result = CheckInRule.evaluate(items)
                XCTAssertEqual(result.percent, completed * 100 / counted)
                XCTAssertEqual(result.percent >= 66, result.meetsThreshold, "\(completed)/\(counted) 顯示 \(result.percent)%")
                XCTAssertEqual(result.meetsThreshold, 3 * completed >= 2 * counted)
            }
        }
    }

    // MARK: 介面提示

    func testWeightNeeded() {
        XCTAssertEqual(CheckInRule.evaluate([study("s"), exercise("e"), habit("h")]).weightNeeded, 4)
        XCTAssertEqual(CheckInRule.evaluate([study("s"), exercise("e", done: true), habit("h", done: true)]).weightNeeded, 1)
        XCTAssertEqual(CheckInRule.evaluate([study("s", done: true), exercise("e"), habit("h", done: true)]).weightNeeded, 0)
        // 8 份要 6 份（3 × 6 ≥ 16），已完成 5 份還差 1 份
        let eight = [study("s"), exercise("e", done: true), habit("h1", done: true), habit("h2", done: true), habit("h3", done: true)]
        XCTAssertEqual(CheckInRule.evaluate(eight).weightNeeded, 1)
    }

    func testSingleCompletionCandidates() {
        XCTAssertEqual(
            CheckInRule.singleCompletionCandidates([study("s"), exercise("e"), habit("h", done: true)]),
            ["s"], "完成學習 4/6 達標；完成運動只有 3/6"
        )
        XCTAssertEqual(
            CheckInRule.singleCompletionCandidates([study("s", done: true), exercise("e", done: true), habit("h", required: true)]),
            ["h"], "只差必做"
        )
        XCTAssertEqual(
            CheckInRule.singleCompletionCandidates([study("s"), exercise("e", rest: .restAllowed), habit("h", done: true)]),
            ["s"], "休息日做運動會讓計入份量變大：3/6 不達標"
        )
        XCTAssertEqual(
            CheckInRule.singleCompletionCandidates([study("s", done: true), exercise("e", done: true), habit("h")]),
            [], "已經達標"
        )
    }

    func testWeightsComeFromConfig() {
        var config = GameConfig.standard
        config.taskWeights[.habit] = 3
        let result = CheckInRule.evaluate([study("s", done: true), habit("h")], config: config)
        XCTAssertEqual(result.countedWeight, 6)
        XCTAssertEqual(result.percent, 50)
        XCTAssertFalse(result.isAchieved)
    }
}
