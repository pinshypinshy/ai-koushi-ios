//
//  CourseItemFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import APIClient
import ComposableArchitecture
@testable import CourseFeature
import Foundation
import Models
import Testing

private let question = ApiQuestion(
    id: "q1",
    stem: "問題",
    choices: [ApiChoice(id: "a", body: "選択肢A"), ApiChoice(id: "b", body: "選択肢B")],
    coveredStepIds: ["s1"]
)
private let response = QuizResponse(questions: [question], latestAttempts: [])

@MainActor
struct CourseItemFeatureTests {
    // MARK: - init

    @Test func init_講義のタブで始まる() {
        let state = CourseItemFeature.State(summary: .mock(), detail: .mock())

        #expect(state.selectedTab == .lecture)
        #expect(state.quiz.courseID == "c1")
    }

    // MARK: - tabSelected

    @Test func tabSelected_確認テストを開くと取得する() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock())) {
            $0.apiClient.quiz = { _ in response }
        }

        await store.send(.tabSelected(.quiz)) { $0.selectedTab = .quiz }
        await receiveQuizFetch(store)
    }

    @Test(arguments: [QuizStatus.pending, .failed])
    func tabSelected_quizStatusがready以外なら取得しない(quizStatus: QuizStatus) async {
        let store = makeStore(.init(summary: .mock(quizStatus: quizStatus), detail: .mock(quizStatus: quizStatus)))

        await store.send(.tabSelected(.quiz)) { $0.selectedTab = .quiz }
    }

    @Test func tabSelected_同じタブなら何もしない() async {
        await makeStore(.init(summary: .mock(), detail: .mock())).send(.tabSelected(.lecture))
    }

    @Test func tabSelected_講義に戻しても途中経過を残す() async {
        var state = CourseItemFeature.State(summary: .mock(), detail: .mock())
        state.selectedTab = .quiz
        state.quiz.screen = .session(.init(mode: .normal, questions: [question], answer: .selecting("a")))
        let store = makeStore(state)

        await store.send(.tabSelected(.lecture)) { $0.selectedTab = .lecture }
        await store.send(.tabSelected(.quiz)) { $0.selectedTab = .quiz }
        // 出題中なので、QuizFeature は取得しない
        await store.receive(\.quiz.fetchRequested)
    }

    // MARK: - refreshQuizIfShown

    @Test func refreshQuizIfShown_講義のタブなら何もしない() async {
        await makeStore(.init(summary: .mock(), detail: .mock())).send(.refreshQuizIfShown)
    }

    @Test func refreshQuizIfShown_確認テストのタブなら取得する() async {
        var state = CourseItemFeature.State(summary: .mock(), detail: .mock())
        state.selectedTab = .quiz
        let store = makeStore(state) {
            $0.apiClient.quiz = { _ in response }
        }

        await store.send(.refreshQuizIfShown)
        await receiveQuizFetch(store)
    }

    // MARK: - displayedTab

    @Test func displayedTab_タブバーを出さない講義では講義になる() {
        var notFetched = CourseItemFeature.State(summary: .mock())
        notFetched.selectedTab = .quiz
        var generating = CourseItemFeature.State(summary: .mock(status: .generating), detail: .mock(status: .generating))
        generating.selectedTab = .quiz
        var ready = CourseItemFeature.State(summary: .mock(), detail: .mock())
        ready.selectedTab = .quiz

        #expect(!notFetched.showsTabBar)
        #expect(notFetched.displayedTab == .lecture)
        #expect(!generating.showsTabBar)
        #expect(generating.displayedTab == .lecture)
        #expect(ready.showsTabBar)
        #expect(ready.displayedTab == .quiz)
    }

    // MARK: - lecture

    @Test func lecture_確認テストへで確認テストのタブを開いて取得する() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock(currentStepId: nil))) {
            $0.apiClient.quiz = { _ in response }
        }

        await store.send(.lecture(.quizButtonTapped))
        await store.receive(\.lecture.delegate.quizRequested) { $0.selectedTab = .quiz }
        await receiveQuizFetch(store)
    }

    // MARK: - quiz

    @Test func quiz_講義へ戻るで講義のタブにする() async {
        var state = CourseItemFeature.State(summary: .mock(), detail: .mock())
        state.selectedTab = .quiz
        state.quiz.screen = .result(.init(mode: .normal, questionCount: 1, wrongQuestions: []))
        let store = makeStore(state)

        await store.send(.quiz(.lectureButtonTapped))
        await store.receive(\.quiz.delegate.lectureRequested) { $0.selectedTab = .lecture }
    }

    // MARK: - 補助

    private func receiveQuizFetch(_ store: TestStoreOf<CourseItemFeature>) async {
        await store.receive(\.quiz.fetchRequested) { $0.quiz.isFetching = true }
        await store.receive(\.quiz.fetchSucceeded) {
            $0.quiz.isFetching = false
            $0.quiz.bank = .init(response)
        }
    }

    private func makeStore(
        _ state: CourseItemFeature.State,
        withDependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<CourseItemFeature> {
        TestStore(initialState: state) {
            CourseItemFeature()
        } withDependencies: {
            withDependencies(&$0)
        }
    }
}

extension CourseSummary {
    fileprivate static func mock(status: CourseStatus = .ready, quizStatus: QuizStatus = .ready) -> CourseSummary {
        CourseSummary(
            id: "c1", title: "講義", status: status, quizStatus: quizStatus, phase: nil, errorMessage: nil,
            totalSteps: 1, completedSteps: 0, updatedAt: 0
        )
    }
}

extension CourseDetail {
    fileprivate static func mock(
        status: CourseStatus = .ready,
        quizStatus: QuizStatus = .ready,
        currentStepId: String? = "s1"
    ) -> CourseDetail {
        CourseDetail(
            summary: .mock(status: status, quizStatus: quizStatus),
            currentStepId: currentStepId,
            steps: [ApiStep(id: "s1", orderIndex: 1, title: "はじめに", status: currentStepId == nil ? .completed : .inProgress)],
            messages: [ApiMessage(id: "m1", stepId: "s1", role: .assistant, content: "本文", interrupted: false)]
        )
    }
}
