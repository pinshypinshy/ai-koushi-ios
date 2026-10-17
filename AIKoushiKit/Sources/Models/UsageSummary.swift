//
//  UsageSummary.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

public struct UsageSummary: Decodable, Equatable, Sendable {
    public let costUsd: Double
    public let costLimitUsd: Double
    public let courses: Int
    public let courseLimit: Int
    /// ミリ秒のエポック時刻
    public let periodStart: Int
    
    public init(costUsd: Double, costLimitUsd: Double, courses: Int, courseLimit: Int, periodStart: Int) {
        self.costUsd = costUsd
        self.costLimitUsd = costLimitUsd
        self.courses = courses
        self.courseLimit = courseLimit
        self.periodStart = periodStart
    }
}
