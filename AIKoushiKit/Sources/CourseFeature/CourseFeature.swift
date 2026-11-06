//
//  CourseFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/29.
//

import AppConfig
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct CourseFeature {
    @ObservableState
    public struct State: Equatable {
        var lectures: IdentifiedArrayOf<LectureFeature.State>
        public internal(set) var selectedCourseID: CourseSummary.ID?

        var selectedLecture: LectureFeature.State? {
            selectedCourseID.flatMap { lectures[id: $0] }
        }

        /// `selected` は、サーバーが返す一覧の先頭の講義の詳細
        public init(courses: [CourseSummary], selected: CourseDetail?) {
            self.lectures = IdentifiedArray(uniqueElements: courses.prefix(1).map { LectureFeature.State(summary: $0, detail: selected) })
            self.selectedCourseID = courses.first?.id
        }
    }

    public enum Action {
        case task
        case menuButtonTapped
        case openWebButtonTapped
        case coursesChanged(courses: [CourseSummary], selectedCourseID: CourseSummary.ID?)
        case lectures(IdentifiedActionOf<LectureFeature>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case sidebarRequested
            case sessionExpired
            case usageRefreshRequested
            case courseUpdated(CourseSummary)
        }
    }

    @Dependency(\.openURL) var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard let lecture = state.selectedLecture else { return .none }
                // 起動直後は bootstrap の selected を使い、取り直さない（§4.6）
                let action: LectureFeature.Action = lecture.detail == nil ? .fetchRequested : .startLectureIfNeeded
                return .send(.lectures(.element(id: lecture.id, action: action)))

            case .menuButtonTapped:
                return .send(.delegate(.sidebarRequested))

            case .openWebButtonTapped:
                return .run { [openURL] _ in
                    await openURL(ServerURL.production)
                }

            case let .coursesChanged(courses, selectedCourseID):
                return updateCourses(&state, courses: courses, selectedCourseID: selectedCourseID)

            case let .lectures(.element(id: _, action: .delegate(delegate))):
                switch delegate {
                case .sessionExpired:
                    return .send(.delegate(.sessionExpired))
                case .usageRefreshRequested:
                    return .send(.delegate(.usageRefreshRequested))
                case let .courseUpdated(course):
                    return .send(.delegate(.courseUpdated(course)))
                }

            case .lectures, .delegate:
                return .none
            }
        }
        .forEach(\.lectures, action: \.lectures) {
            LectureFeature()
        }
    }

    private func updateCourses(
        _ state: inout State,
        courses: [CourseSummary],
        selectedCourseID: CourseSummary.ID?
    ) -> Effect<Action> {
        let isSelectionChanged = selectedCourseID != state.selectedCourseID
        state.selectedCourseID = selectedCourseID
        state.lectures.removeAll { lecture in !courses.contains { $0.id == lecture.id } }
        for course in courses {
            state.lectures[id: course.id]?.summary = course
        }

        guard let selectedCourseID, let selected = courses.first(where: { $0.id == selectedCourseID }) else { return .none }
        if state.lectures[id: selectedCourseID] == nil {
            state.lectures.append(LectureFeature.State(summary: selected))
        }
        guard isSelectionChanged || state.lectures[id: selectedCourseID]?.isStatusOutdated == true else { return .none }
        // forEach を通さないと、キャンセルの ID が講義ごとに分かれない（ADR 0004）
        return .send(.lectures(.element(id: selectedCourseID, action: .fetchRequested)))
    }
}
