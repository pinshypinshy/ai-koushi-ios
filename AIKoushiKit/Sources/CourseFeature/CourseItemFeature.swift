//
//  CourseItemFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

import ComposableArchitecture
import Models

/// 講義1つ分の状態をまとめる（ADR 0008）
@Reducer
public struct CourseItemFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let id: CourseSummary.ID
        var lecture: LectureFeature.State

        public init(summary: CourseSummary, detail: CourseDetail? = nil) {
            self.id = summary.id
            self.lecture = LectureFeature.State(summary: summary, detail: detail)
        }
    }

    public enum Action {
        case lecture(LectureFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.lecture, action: \.lecture) {
            LectureFeature()
        }
    }
}
