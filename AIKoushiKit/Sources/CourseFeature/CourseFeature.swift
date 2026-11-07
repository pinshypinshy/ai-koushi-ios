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
        var items: IdentifiedArrayOf<CourseItemFeature.State>
        public internal(set) var selectedCourseID: CourseSummary.ID?

        var selectedItem: CourseItemFeature.State? {
            selectedCourseID.flatMap { items[id: $0] }
        }

        /// `selected` は、サーバーが返す一覧の先頭の講義の詳細
        public init(courses: [CourseSummary], selected: CourseDetail?) {
            self.items = IdentifiedArray(uniqueElements: courses.prefix(1).map { CourseItemFeature.State(summary: $0, detail: selected) })
            self.selectedCourseID = courses.first?.id
        }
    }

    public enum Action {
        case task
        case menuButtonTapped
        case openWebButtonTapped
        case coursesChanged(courses: [CourseSummary], selectedCourseID: CourseSummary.ID?)
        case items(IdentifiedActionOf<CourseItemFeature>)
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
                guard let item = state.selectedItem else { return .none }
                // 起動直後は bootstrap の selected を使い、取り直さない（§4.6）
                let action: LectureFeature.Action = item.lecture.detail == nil ? .fetchRequested : .startLectureIfNeeded
                return .send(.items(.element(id: item.id, action: .lecture(action))))

            case .menuButtonTapped:
                return .send(.delegate(.sidebarRequested))

            case .openWebButtonTapped:
                return .run { [openURL] _ in
                    await openURL(ServerURL.production)
                }

            case let .coursesChanged(courses, selectedCourseID):
                return updateCourses(&state, courses: courses, selectedCourseID: selectedCourseID)

            case let .items(.element(id: _, action: .lecture(.delegate(delegate)))):
                switch delegate {
                case .sessionExpired:
                    return .send(.delegate(.sessionExpired))
                case .usageRefreshRequested:
                    return .send(.delegate(.usageRefreshRequested))
                case let .courseUpdated(course):
                    return .send(.delegate(.courseUpdated(course)))
                }

            case .items, .delegate:
                return .none
            }
        }
        .forEach(\.items, action: \.items) {
            CourseItemFeature()
        }
    }

    private func updateCourses(
        _ state: inout State,
        courses: [CourseSummary],
        selectedCourseID: CourseSummary.ID?
    ) -> Effect<Action> {
        let isSelectionChanged = selectedCourseID != state.selectedCourseID
        state.selectedCourseID = selectedCourseID
        state.items.removeAll { item in !courses.contains { $0.id == item.id } }
        for course in courses {
            state.items[id: course.id]?.lecture.summary = course
        }

        guard let selectedCourseID, let selected = courses.first(where: { $0.id == selectedCourseID }) else { return .none }
        if state.items[id: selectedCourseID] == nil {
            state.items.append(CourseItemFeature.State(summary: selected))
        }
        guard isSelectionChanged || state.items[id: selectedCourseID]?.lecture.isStatusOutdated == true else { return .none }
        // forEach を通さないと、キャンセルの ID が講義ごとに分かれない（ADR 0004）
        return .send(.items(.element(id: selectedCourseID, action: .lecture(.fetchRequested))))
    }
}
