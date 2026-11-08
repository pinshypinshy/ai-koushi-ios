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
        var quiz: QuizFeature.State
        var selectedTab: Tab = .lecture

        public init(summary: CourseSummary, detail: CourseDetail? = nil) {
            self.id = summary.id
            self.lecture = LectureFeature.State(summary: summary, detail: detail)
            self.quiz = QuizFeature.State(courseID: summary.id)
        }

        var showsTabBar: Bool {
            lecture.displayedStatus == .ready && lecture.detail != nil
        }

        var displayedTab: Tab {
            showsTabBar ? selectedTab : .lecture
        }

        var quizStatus: QuizStatus {
            lecture.summary.quizStatus
        }
    }

    public enum Tab: Equatable, Sendable {
        case lecture
        case quiz
    }

    public enum Action {
        case lecture(LectureFeature.Action)
        case quiz(QuizFeature.Action)
        case tabSelected(Tab)
        case refreshQuizIfShown
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.lecture, action: \.lecture) {
            LectureFeature()
        }
        Scope(state: \.quiz, action: \.quiz) {
            QuizFeature()
        }
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                return select(tab, &state)

            case .lecture(.delegate(.quizRequested)):
                return select(.quiz, &state)

            case .quiz(.delegate(.lectureRequested)):
                state.selectedTab = .lecture
                return .none

            case .refreshQuizIfShown:
                return refreshQuizIfShown(state)

            case .lecture, .quiz:
                return .none
            }
        }
    }

    private func select(_ tab: Tab, _ state: inout State) -> Effect<Action> {
        guard tab != state.selectedTab else { return .none }
        state.selectedTab = tab
        return refreshQuizIfShown(state)
    }

    private func refreshQuizIfShown(_ state: State) -> Effect<Action> {
        guard state.displayedTab == .quiz, state.quizStatus == .ready else { return .none }
        return .send(.quiz(.fetchRequested))
    }
}
