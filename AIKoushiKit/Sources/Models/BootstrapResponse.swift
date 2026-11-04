//
//  BootstrapResponse.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

public struct BootstrapResponse: Decodable, Equatable, Sendable {
    public let user: ApiUser
    public let courses: [CourseSummary]
    public let selected: CourseDetail?
    public let usage: UsageSummary
    
    public init(user: ApiUser, courses: [CourseSummary], selected: CourseDetail?, usage: UsageSummary) {
        self.user = user
        self.courses = courses
        self.selected = selected
        self.usage = usage
    }
}
