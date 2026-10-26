//
//  UsageMeter.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import Models

struct UsageMeter: Equatable {
    enum Level: Equatable {
        case normal
        case warning
        case limit

        init(percent: Int) {
            if percent >= 100 {
                self = .limit
            } else if percent >= 80 {
                self = .warning
            } else {
                self = .normal
            }
        }
    }

    let costPercent: Int
    let coursePercent: Int

    init(usage: UsageSummary) {
        self.costPercent = Self.percent(used: usage.costUsd, limit: usage.costLimitUsd)
        self.coursePercent = Self.percent(used: Double(usage.courses), limit: Double(usage.courseLimit))
    }

    var costLevel: Level { Level(percent: costPercent) }
    var courseLevel: Level { Level(percent: coursePercent) }
    var overallLevel: Level { Level(percent: max(costPercent, coursePercent)) }

    var notice: String? {
        switch overallLevel {
        case .normal: nil
        case .warning: "上限に近づいています。"
        case .limit: "上限に達しました。新しい講義は作成できません。"
        }
    }

    static func percent(used: Double, limit: Double) -> Int {
        guard limit > 0 else { return 0 }
        return Int(min(100, (used / limit * 100).rounded()))
    }
}
