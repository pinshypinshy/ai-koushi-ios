//
//  BootstrapResponse.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

public struct BootstrapResponse: Decodable, Equatable, Sendable {
  public let user: ApiUser
  public let courses: [CourseSummary]
  public let usage: UsageSummary
  // selected（CourseDetail）は段階2で加える。宣言しない項目は読み込み時に無視される

  public init(user: ApiUser, courses: [CourseSummary], usage: UsageSummary) {
    self.user = user
    self.courses = courses
    self.usage = usage
  }
}
