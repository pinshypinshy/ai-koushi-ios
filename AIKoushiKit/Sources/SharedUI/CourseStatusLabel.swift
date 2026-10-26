//
//  CourseStatusLabel.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import Models
import SwiftUI

/// サイドバーの行（§3.4）と選択中の講義（§3.2）で同じ表示にするための部品
public struct CourseStatusLabel: View {
    let course: CourseSummary

    public init(course: CourseSummary) {
        self.course = course
    }

    public var body: some View {
        Group {
            switch course.status {
            case .ready:
                if course.totalSteps > 0 {
                    Text("\(course.completedSteps) / \(course.totalSteps)")
                        .monospacedDigit()
                        .foregroundStyle(AppColor.secondaryText)
                }
            case .generating:
                Text("生成中")
                    .foregroundStyle(AppColor.secondaryText)
            case .failed:
                Text("生成に失敗しました")
                    .foregroundStyle(AppColor.error)
            }
        }
        .font(.footnote)
    }
}
