//
//  UsageMeterTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import Models
@testable import SidebarFeature
import Testing

struct UsageMeterTests {
    @Test(arguments: [
        (1.0, 8.0, 13),     // 12.5 は切り上げる
        (1.0, 3.0, 33),
        (0.0, 1.0, 0),
        (1.5, 1.0, 100),    // 上限を超えても 100
        (1.0, 0.0, 0),      // 上限が0以下
        (1.0, -1.0, 0),
    ])
    func percent(used: Double, limit: Double, expected: Int) {
        #expect(UsageMeter.percent(used: used, limit: limit) == expected)
    }

    @Test(arguments: [
        (0, UsageMeter.Level.normal),
        (79, .normal),
        (80, .warning),
        (99, .warning),
        (100, .limit),
    ])
    func level(percent: Int, expected: UsageMeter.Level) {
        #expect(UsageMeter.Level(percent: percent) == expected)
    }

    @Test func noticeFollowsLargerOfTwo() {
        #expect(meter(costPercent: 10, courses: 1).notice == nil)
        #expect(meter(costPercent: 10, courses: 8).notice == "上限に近づいています。")
        #expect(meter(costPercent: 85, courses: 1).notice == "上限に近づいています。")
        #expect(meter(costPercent: 85, courses: 10).notice == "上限に達しました。新しい講義は作成できません。")
    }

    @Test func eachBarHasItsOwnLevel() {
        let usage = meter(costPercent: 85, courses: 1)
        #expect(usage.costLevel == .warning)
        #expect(usage.courseLevel == .normal)
    }

    private func meter(costPercent: Double, courses: Int) -> UsageMeter {
        UsageMeter(usage: UsageSummary(costUsd: costPercent / 100, costLimitUsd: 1, courses: courses, courseLimit: 10, periodStart: 0))
    }
}
