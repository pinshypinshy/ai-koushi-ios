//
//  QuizFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

import APIClient
import ComposableArchitecture
@testable import CourseFeature
import Foundation
import Models
import Testing

private let q1 = ApiQuestion.mock("q1", steps: ["s1"])
private let q2 = ApiQuestion.mock("q2", steps: ["s2"])
private let q3 = ApiQuestion.mock("q3", steps: ["s1", "s3"])
private let questions = [q1, q2, q3]

private let correctResult = AttemptResult(questionId: "q1", selectedChoiceId: "a", correctChoiceId: "a", isCorrect: true, explanation: "解説")
private let wrongResult = AttemptResult(questionId: "q1", selectedChoiceId: "b", correctChoiceId: "a", isCorrect: false, explanation: "解説")

/// シャッフルで順が変わる値を返す。常に 0 を返すと順が変わらず、シャッフルを確かめられない
private struct MaxGenerator: RandomNumberGenerator, Sendable {
    mutating func next() -> UInt64 { .max }
}

private func shuffled(_ questions: [ApiQuestion]) -> [ApiQuestion] {
    var generator = MaxGenerator()
    return questions.shuffled(using: &generator)
}

@MainActor
struct QuizFeatureTests {
    // MARK: - fetchRequested

    @Test(arguments: [true, false])
    func fetchRequested_開始画面でなければ何もしない(isSession: Bool) async {
        var state = loaded()
        state.screen = isSession
            ? .session(.init(mode: .normal, questions: questions))
            : .result(.init(mode: .normal, questionCount: 3, wrongQuestions: []))

        await makeStore(state).send(.fetchRequested)
    }

    @Test func fetchRequested_エラーを消して取得を始める() async {
        let response = QuizResponse(questions: questions, latestAttempts: [])
        let requestedID = LockIsolated<String?>(nil)
        var state = QuizFeature.State(courseID: "c1")
        state.fetchError = .network
        let store = makeStore(state) {
            $0.apiClient.quiz = { id in
                requestedID.setValue(id)
                return response
            }
        }

        await store.send(.fetchRequested) {
            $0.isFetching = true
            $0.fetchError = nil
        }
        await store.receive(\.fetchSucceeded) {
            $0.isFetching = false
            $0.bank = .init(response)
        }
        #expect(requestedID.value == "c1")
    }

    // MARK: - retryFetchButtonTapped

    @Test func retryFetchButtonTapped_取得し直す() async {
        var state = QuizFeature.State(courseID: "c1")
        state.fetchError = .other
        let store = makeStore(state) {
            $0.apiClient.quiz = { _ in throw APIClientError.network }
        }

        await store.send(.retryFetchButtonTapped) {
            $0.isFetching = true
            $0.fetchError = nil
        }
        await store.receive(\.fetchFailed) {
            $0.isFetching = false
            $0.fetchError = .network
        }
    }

    // MARK: - fetchSucceeded

    @Test func fetchSucceeded_設問と最新の解答を持つ() async {
        var state = QuizFeature.State(courseID: "c1")
        state.isFetching = true
        let response = QuizResponse(
            questions: questions,
            latestAttempts: [.init(questionId: "q1", isCorrect: true), .init(questionId: "q2", isCorrect: false)]
        )

        await makeStore(state).send(.fetchSucceeded(response)) {
            $0.isFetching = false
            $0.bank = .init(response)
        }
        #expect(QuizFeature.QuestionBank(response).latestIsCorrect == ["q1": true, "q2": false])
    }

    @Test func fetchSucceeded_同じ設問の解答が重複しても落ちない() {
        let response = QuizResponse(
            questions: questions,
            latestAttempts: [.init(questionId: "q1", isCorrect: true), .init(questionId: "q1", isCorrect: false)]
        )

        #expect(QuizFeature.QuestionBank(response).latestIsCorrect == ["q1": false])
    }

    // MARK: - fetchFailed

    @Test(arguments: [
        (APIClientError.http(status: 404, body: nil), QuizFeature.FetchError.notFound),
        (.network, .network),
        (.http(status: 500, body: nil), .other),
        (.decoding, .other),
    ])
    func fetchFailed_結果ごとのエラーを表示する(error: APIClientError, expected: QuizFeature.FetchError) async {
        var state = QuizFeature.State(courseID: "c1")
        state.isFetching = true

        await makeStore(state).send(.fetchFailed(error)) {
            $0.isFetching = false
            $0.fetchError = expected
        }
    }

    @Test func fetchFailed_取得済みなら表示を残す() async {
        var state = loaded()
        state.isFetching = true

        await makeStore(state).send(.fetchFailed(APIClientError.network)) {
            $0.isFetching = false
            $0.fetchError = .network
        }
    }

    @Test func fetchFailed_401ならセッション切れにする() async {
        var state = QuizFeature.State(courseID: "c1")
        state.isFetching = true
        let store = makeStore(state)

        await store.send(.fetchFailed(APIClientError.http(status: 401, body: nil))) {
            $0.isFetching = false
        }
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func fetchFailed_取り消しでは何もしない() async {
        var state = QuizFeature.State(courseID: "c1")
        state.isFetching = true

        await makeStore(state).send(.fetchFailed(CancellationError()))
    }

    // MARK: - stepFilterToggled

    @Test func stepFilterToggled_選択を切り替える() async {
        let store = makeStore(loaded())

        await store.send(.stepFilterToggled("s1")) { $0.stepFilter = ["s1"] }
        await store.send(.stepFilterToggled("s2")) { $0.stepFilter = ["s1", "s2"] }
        await store.send(.stepFilterToggled("s1")) { $0.stepFilter = ["s2"] }
    }

    // MARK: - startButtonTapped

    @Test func startButtonTapped_絞り込んだ設問をシャッフルして始める() async {
        var state = loaded()
        state.stepFilter = ["s1"]
        let expected = shuffled([q1, q3])
        #expect(expected != [q1, q3])

        await makeStore(state).send(.startButtonTapped) {
            $0.screen = .session(.init(mode: .normal, questions: expected))
        }
    }

    @Test func startButtonTapped_出題数が0なら何もしない() async {
        var state = loaded()
        state.stepFilter = ["s9"]

        await makeStore(state).send(.startButtonTapped)
    }

    @Test func startButtonTapped_未取得なら何もしない() async {
        await makeStore(.init(courseID: "c1")).send(.startButtonTapped)
    }

    @Test func startButtonTapped_取り直しをやめる() async {
        let store = makeStore(loaded()) {
            $0.apiClient.quiz = { _ in
                try await Task.sleep(for: .seconds(3600))
                return QuizResponse(questions: [], latestAttempts: [])
            }
        }

        await store.send(.fetchRequested) { $0.isFetching = true }
        await store.send(.startButtonTapped) {
            $0.isFetching = false
            $0.screen = .session(.init(mode: .normal, questions: shuffled(questions)))
        }
        await store.finish()
    }

    // MARK: - reviewButtonTapped

    @Test func reviewButtonTapped_最新が誤答の設問だけを出題する() async {
        var state = loaded(latest: ["q1": false, "q2": true, "q3": false])
        state.stepFilter = ["s2"]
        let expected = shuffled([q1, q3])

        await makeStore(state).send(.reviewButtonTapped) {
            $0.screen = .session(.init(mode: .review, questions: expected))
        }
    }

    @Test func reviewButtonTapped_誤答が0問なら何もしない() async {
        await makeStore(loaded(latest: ["q1": true])).send(.reviewButtonTapped)
    }

    @Test func reviewButtonTapped_結果の画面から再挑戦できる() async {
        var state = loaded(latest: ["q1": false])
        state.screen = .result(.init(mode: .normal, questionCount: 3, wrongQuestions: [q1]))

        await makeStore(state).send(.reviewButtonTapped) {
            $0.screen = .session(.init(mode: .review, questions: [q1]))
        }
    }

    @Test func reviewButtonTapped_テストの途中では何もしない() async {
        await makeStore(session(latest: ["q2": false])).send(.reviewButtonTapped)
    }

    // MARK: - choiceTapped

    @Test func choiceTapped_選び直せる() async {
        let store = makeStore(session())

        await store.send(.choiceTapped("a")) { $0.screen = sessionScreen(answer: .selecting("a")) }
        await store.send(.choiceTapped("b")) { $0.screen = sessionScreen(answer: .selecting("b")) }
    }

    @Test(arguments: [QuizFeature.Answer.grading("a"), .answered(correctResult)])
    func choiceTapped_採点中と回答後は変えられない(answer: QuizFeature.Answer) async {
        await makeStore(session(answer: answer)).send(.choiceTapped("b"))
    }

    // MARK: - submitButtonTapped

    @Test func submitButtonTapped_選ぶまで何もしない() async {
        await makeStore(session()).send(.submitButtonTapped)
    }

    @Test func submitButtonTapped_エラーを消して解答を送る() async {
        let sent = LockIsolated<[String]>([])
        let store = makeStore(session(answer: .selecting("a"), errorMessage: "前回のエラー")) {
            $0.apiClient.attempt = { questionID, choiceID in
                sent.setValue([questionID, choiceID])
                return correctResult
            }
        }

        await store.send(.submitButtonTapped) { $0.screen = sessionScreen(answer: .grading("a")) }
        await store.receive(\.attemptSucceeded) {
            $0.bank?.latestIsCorrect["q1"] = true
            $0.screen = sessionScreen(answer: .answered(correctResult))
        }
        #expect(sent.value == ["q1", "a"])
    }

    @Test func submitButtonTapped_採点中は2回目を送らない() async {
        await makeStore(session(answer: .grading("a"))).send(.submitButtonTapped)
    }

    // MARK: - attemptSucceeded

    @Test func attemptSucceeded_正解なら誤答に足さない() async {
        await makeStore(session(answer: .grading("a"))).send(.attemptSucceeded(correctResult)) {
            $0.bank?.latestIsCorrect["q1"] = true
            $0.screen = sessionScreen(answer: .answered(correctResult))
        }
    }

    @Test func attemptSucceeded_不正解なら誤答に足す() async {
        await makeStore(session(answer: .grading("b"))).send(.attemptSucceeded(wrongResult)) {
            $0.bank?.latestIsCorrect["q1"] = false
            $0.screen = sessionScreen(wrongQuestions: [q1], answer: .answered(wrongResult))
        }
    }

    @Test func attemptSucceeded_最新の解答を更新する() async {
        await makeStore(session(latest: ["q1": false], answer: .grading("a"))).send(.attemptSucceeded(correctResult)) {
            $0.bank?.latestIsCorrect["q1"] = true
            $0.screen = sessionScreen(answer: .answered(correctResult))
        }
    }

    // MARK: - attemptFailed

    @Test func attemptFailed_通信エラーなら文言を出して選択を残す() async {
        await makeStore(session(answer: .grading("a"))).send(.attemptFailed(APIClientError.network)) {
            $0.screen = sessionScreen(answer: .selecting("a"), errorMessage: LectureFeature.networkErrorMessage)
        }
    }

    @Test(arguments: [
        APIClientError.http(status: 400, body: nil),
        .http(status: 404, body: nil),
        .http(status: 500, body: nil),
        .decoding,
    ])
    func attemptFailed_その他は採点できないと表示して選択を残す(error: APIClientError) async {
        await makeStore(session(answer: .grading("a"))).send(.attemptFailed(error)) {
            $0.screen = sessionScreen(answer: .selecting("a"), errorMessage: QuizFeature.attemptOtherErrorMessage)
        }
    }

    @Test func attemptFailed_401ならセッション切れにする() async {
        let store = makeStore(session(answer: .grading("a")))

        await store.send(.attemptFailed(APIClientError.http(status: 401, body: nil)))
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func attemptFailed_取り消しでは何もしない() async {
        await makeStore(session(answer: .grading("a"))).send(.attemptFailed(CancellationError()))
    }

    // MARK: - nextButtonTapped

    @Test func nextButtonTapped_次の問題へ進む() async {
        await makeStore(session(wrongQuestions: [q1], answer: .answered(wrongResult))).send(.nextButtonTapped) {
            $0.screen = sessionScreen(index: 1, wrongQuestions: [q1])
        }
    }

    @Test func nextButtonTapped_回答する前は何もしない() async {
        await makeStore(session(answer: .selecting("a"))).send(.nextButtonTapped)
    }

    @Test func nextButtonTapped_最後の問題なら結果を表示する() async {
        var state = session(wrongQuestions: [q1], answer: .answered(correctResult))
        state.screen = sessionScreen(index: 2, wrongQuestions: [q1], answer: .answered(correctResult))

        await makeStore(state).send(.nextButtonTapped) {
            $0.screen = .result(.init(mode: .normal, questionCount: 3, wrongQuestions: [q1]))
        }
    }

    // MARK: - quitButtonTapped

    @Test func quitButtonTapped_開始画面へ戻って取得する() async {
        let response = QuizResponse(questions: questions, latestAttempts: [.init(questionId: "q1", isCorrect: true)])
        let store = makeStore(session(answer: .answered(correctResult))) {
            $0.apiClient.quiz = { _ in response }
        }

        await store.send(.quitButtonTapped) {
            $0.screen = .start
            $0.isFetching = true
        }
        await store.receive(\.fetchSucceeded) {
            $0.isFetching = false
            $0.bank = .init(response)
        }
    }

    @Test func quitButtonTapped_採点中は何もしない() async {
        await makeStore(session(answer: .grading("a"))).send(.quitButtonTapped)
    }

    @Test func quitButtonTapped_解答済みの記録を残す() async {
        let store = makeStore(session(answer: .grading("a"))) {
            $0.apiClient.quiz = { _ in throw APIClientError.network }
        }

        await store.send(.attemptSucceeded(correctResult)) {
            $0.bank?.latestIsCorrect["q1"] = true
            $0.screen = sessionScreen(answer: .answered(correctResult))
        }
        await store.send(.quitButtonTapped) {
            $0.screen = .start
            $0.isFetching = true
        }
        await store.receive(\.fetchFailed) {
            $0.isFetching = false
            $0.fetchError = .network
        }
        #expect(store.state.bank?.latestIsCorrect["q1"] == true)
    }

    // MARK: - backToStartButtonTapped

    @Test func backToStartButtonTapped_開始画面へ戻って取得する() async {
        var state = loaded()
        state.stepFilter = ["s1"]
        state.screen = .result(.init(mode: .normal, questionCount: 3, wrongQuestions: []))
        let response = QuizResponse(questions: questions, latestAttempts: [])
        let store = makeStore(state) {
            $0.apiClient.quiz = { _ in response }
        }

        await store.send(.backToStartButtonTapped) {
            $0.screen = .start
            $0.isFetching = true
        }
        await store.receive(\.fetchSucceeded) {
            $0.isFetching = false
            $0.bank = .init(response)
        }
    }

    // MARK: - lectureButtonTapped

    @Test func lectureButtonTapped_画面を変えず親に知らせる() async {
        var state = loaded()
        state.screen = .result(.init(mode: .normal, questionCount: 3, wrongQuestions: []))
        let store = makeStore(state)

        await store.send(.lectureButtonTapped)
        await store.receive(\.delegate.lectureRequested)
    }

    // MARK: - 計算

    @Test func overallRate_最新の解答だけを数える() {
        let rate = loaded(latest: ["q1": true, "q2": false]).overallRate

        #expect(rate == .init(correctCount: 1, answeredCount: 2))
        #expect(rate?.percent == 50)
    }

    @Test func overallRate_未解答ならnilになる() {
        #expect(loaded().overallRate == nil)
    }

    @Test func percent_四捨五入する() {
        #expect(QuizFeature.AnswerRate(correctCount: 2, answeredCount: 3).percent == 67)
        #expect(QuizFeature.AnswerRate(correctCount: 1, answeredCount: 3).percent == 33)
    }

    @Test func filteredQuestions_何も選ばなければ全問を返す() {
        #expect(loaded().filteredQuestions == questions)
    }

    @Test func filteredQuestions_選んだステップの和集合を返す() {
        var state = loaded()
        state.stepFilter = ["s2", "s3"]

        #expect(state.filteredQuestions == [q2, q3])
    }

    @Test func stepStats_ステップごとの問数と割合を返す() {
        let state = loaded(latest: ["q1": true, "q3": false])

        #expect(state.stepStats(for: "s1") == .init(questionCount: 2, rate: .init(correctCount: 1, answeredCount: 2)))
        #expect(state.stepStats(for: "s2") == .init(questionCount: 1, rate: nil))
    }

    // MARK: - 補助

    private func loaded(latest: [String: Bool] = [:]) -> QuizFeature.State {
        var state = QuizFeature.State(courseID: "c1")
        state.bank = .init(
            QuizResponse(
                questions: questions,
                latestAttempts: latest.map { AttemptSummary(questionId: $0.key, isCorrect: $0.value) }
            )
        )
        return state
    }

    private func session(
        latest: [String: Bool] = [:],
        wrongQuestions: [ApiQuestion] = [],
        answer: QuizFeature.Answer = .selecting(nil),
        errorMessage: String? = nil
    ) -> QuizFeature.State {
        var state = loaded(latest: latest)
        state.screen = sessionScreen(wrongQuestions: wrongQuestions, answer: answer, errorMessage: errorMessage)
        return state
    }

    private func sessionScreen(
        index: Int = 0,
        wrongQuestions: [ApiQuestion] = [],
        answer: QuizFeature.Answer = .selecting(nil),
        errorMessage: String? = nil
    ) -> QuizFeature.Screen {
        .session(
            .init(mode: .normal, questions: questions, index: index, wrongQuestions: wrongQuestions, answer: answer, errorMessage: errorMessage)
        )
    }

    private func makeStore(
        _ state: QuizFeature.State,
        withDependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<QuizFeature> {
        TestStore(initialState: state) {
            QuizFeature()
        } withDependencies: {
            $0.withRandomNumberGenerator = WithRandomNumberGenerator(MaxGenerator())
            withDependencies(&$0)
        }
    }
}

extension ApiQuestion {
    fileprivate static func mock(_ id: String, steps: [String]) -> ApiQuestion {
        ApiQuestion(
            id: id,
            stem: "問題 \(id)",
            choices: [ApiChoice(id: "a", body: "選択肢A"), ApiChoice(id: "b", body: "選択肢B")],
            coveredStepIds: steps
        )
    }
}
