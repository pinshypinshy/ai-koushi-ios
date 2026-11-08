//
//  QuizFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

import APIClient
import ComposableArchitecture
import Foundation
import MarkdownWebView
import Models

/// 講義1つ分の確認テスト
@Reducer
public struct QuizFeature {
    @ObservableState
    public struct State: Equatable {
        let courseID: CourseSummary.ID
        var bank: QuestionBank?
        var isFetching = false
        var fetchError: FetchError?
        var stepFilter: Set<ApiStep.ID> = []
        var screen: Screen = .start

        public init(courseID: CourseSummary.ID) {
            self.courseID = courseID
        }
    }

    struct QuestionBank: Equatable {
        var questions: [ApiQuestion]
        var latestIsCorrect: [ApiQuestion.ID: Bool]

        init(_ response: QuizResponse) {
            questions = response.questions
            // サーバーは同じ時刻の解答を両方返しうるので、キーの重複を許す
            latestIsCorrect = Dictionary(
                response.latestAttempts.map { ($0.questionId, $0.isCorrect) },
                uniquingKeysWith: { _, last in last }
            )
        }
    }

    enum Screen: Equatable {
        case start
        case session(Session)
        case result(QuizResult)
    }

    enum Mode: Equatable {
        case normal
        case review
    }

    struct Session: Equatable {
        let mode: Mode
        let questions: [ApiQuestion]
        var index = 0
        var wrongQuestions: [ApiQuestion] = []
        var answer: Answer = .selecting(nil)
        var errorMessage: String?

        var currentQuestion: ApiQuestion { questions[index] }
        var isLastQuestion: Bool { index >= questions.count - 1 }
    }

    enum Answer: Equatable {
        case selecting(ApiChoice.ID?)
        case grading(ApiChoice.ID)
        case answered(AttemptResult)
    }

    struct QuizResult: Equatable {
        let mode: Mode
        let questionCount: Int
        let wrongQuestions: [ApiQuestion]

        var rate: AnswerRate {
            AnswerRate(correctCount: questionCount - wrongQuestions.count, answeredCount: questionCount)
        }
    }

    enum FetchError: Equatable {
        case notFound
        case network
        case other

        var message: String {
            switch self {
            case .notFound: "講義が見つかりませんでした。サイドバーの一覧を下に引っ張って更新してください。"
            case .network: LectureFeature.networkErrorMessage
            case .other: "確認テストを読み込めませんでした。時間をおいて再度お試しください。"
            }
        }

        var canRetry: Bool {
            self != .notFound
        }
    }

    struct AnswerRate: Equatable {
        let correctCount: Int
        let answeredCount: Int

        var percent: Int {
            Int((Double(correctCount) / Double(answeredCount) * 100).rounded())
        }
    }

    struct StepStats: Equatable {
        let questionCount: Int
        let rate: AnswerRate?
    }

    public enum Action {
        case fetchRequested
        case retryFetchButtonTapped
        case stepFilterToggled(ApiStep.ID)
        case startButtonTapped
        case reviewButtonTapped
        case choiceTapped(ApiChoice.ID)
        case submitButtonTapped
        case nextButtonTapped
        case quitButtonTapped
        case backToStartButtonTapped
        case lectureButtonTapped
        case linkTapped(URL)

        case fetchSucceeded(QuizResponse)
        case fetchFailed(any Error)
        case attemptSucceeded(AttemptResult)
        case attemptFailed(any Error)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case sessionExpired
            case lectureRequested
        }
    }

    static let attemptOtherErrorMessage = "採点できませんでした。時間をおいて再度お試しください。"

    private enum CancelID { case fetch, attempt }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchRequested, .retryFetchButtonTapped:
                return fetch(&state)

            case let .fetchSucceeded(response):
                state.isFetching = false
                state.bank = QuestionBank(response)
                return .none

            case let .fetchFailed(error):
                if error is CancellationError { return .none }
                state.isFetching = false
                switch error {
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                case APIClientError.http(status: 404, body: _):
                    state.fetchError = .notFound
                case APIClientError.network:
                    state.fetchError = .network
                default:
                    state.fetchError = .other
                }
                return .none

            case let .stepFilterToggled(stepID):
                if state.stepFilter.remove(stepID) == nil {
                    state.stepFilter.insert(stepID)
                }
                return .none

            case .startButtonTapped:
                guard state.screen == .start else { return .none }
                return begin(&state, mode: .normal, questions: state.filteredQuestions)

            case .reviewButtonTapped:
                if case .session = state.screen { return .none }
                return begin(&state, mode: .review, questions: state.reviewQuestions)

            case let .choiceTapped(choiceID):
                guard case var .session(session) = state.screen, case .selecting = session.answer else { return .none }
                session.answer = .selecting(choiceID)
                state.screen = .session(session)
                return .none

            case .submitButtonTapped:
                return submit(&state)

            case let .attemptSucceeded(result):
                state.bank?.latestIsCorrect[result.questionId] = result.isCorrect
                guard case var .session(session) = state.screen, case .grading = session.answer else { return .none }
                if !result.isCorrect {
                    session.wrongQuestions.append(session.currentQuestion)
                }
                session.answer = .answered(result)
                state.screen = .session(session)
                return .none

            case let .attemptFailed(error):
                switch error {
                case is CancellationError:
                    return .none
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                case APIClientError.network:
                    failAttempt(&state, message: LectureFeature.networkErrorMessage)
                default:
                    failAttempt(&state, message: Self.attemptOtherErrorMessage)
                }
                return .none

            case .nextButtonTapped:
                guard case var .session(session) = state.screen, case .answered = session.answer else { return .none }
                if session.isLastQuestion {
                    state.screen = .result(
                        QuizResult(mode: session.mode, questionCount: session.questions.count, wrongQuestions: session.wrongQuestions)
                    )
                } else {
                    session.index += 1
                    session.answer = .selecting(nil)
                    state.screen = .session(session)
                }
                return .none

            case .quitButtonTapped:
                guard case let .session(session) = state.screen else { return .none }
                if case .grading = session.answer { return .none }
                state.screen = .start
                return fetch(&state)

            case .backToStartButtonTapped:
                guard case .result = state.screen else { return .none }
                state.screen = .start
                return fetch(&state)

            case .lectureButtonTapped:
                return .send(.delegate(.lectureRequested))

            case let .linkTapped(url):
                return .run { [openURL] _ in
                    await openURL(url)
                }

            case .delegate:
                return .none
            }
        }
    }

    private func fetch(_ state: inout State) -> Effect<Action> {
        guard state.screen == .start else { return .none }
        state.isFetching = true
        state.fetchError = nil
        return .run { [apiClient, courseID = state.courseID] send in
            do {
                await send(.fetchSucceeded(try await apiClient.quiz(courseId: courseID)))
            } catch {
                await send(.fetchFailed(error))
            }
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }

    private func begin(_ state: inout State, mode: Mode, questions: [ApiQuestion]) -> Effect<Action> {
        guard !questions.isEmpty else { return .none }
        let shuffled = withRandomNumberGenerator { questions.shuffled(using: &$0) }
        state.screen = .session(Session(mode: mode, questions: shuffled))
        state.isFetching = false
        // 届いた古い解答で、これから記録する解答を上書きしないため（§4.15）
        return .cancel(id: CancelID.fetch)
    }

    private func submit(_ state: inout State) -> Effect<Action> {
        guard case var .session(session) = state.screen, case let .selecting(choiceID?) = session.answer else { return .none }
        session.answer = .grading(choiceID)
        session.errorMessage = nil
        state.screen = .session(session)
        return .run { [apiClient, questionID = session.currentQuestion.id] send in
            do {
                await send(.attemptSucceeded(try await apiClient.attempt(questionId: questionID, selectedChoiceId: choiceID)))
            } catch {
                await send(.attemptFailed(error))
            }
        }
        .cancellable(id: CancelID.attempt)
    }

    private func failAttempt(_ state: inout State, message: String) {
        guard case var .session(session) = state.screen, case let .grading(choiceID) = session.answer else { return }
        session.answer = .selecting(choiceID)
        session.errorMessage = message
        state.screen = .session(session)
    }
}

extension QuizFeature.State {
    var filteredQuestions: [ApiQuestion] {
        let questions = bank?.questions ?? []
        guard !stepFilter.isEmpty else { return questions }
        return questions.filter { $0.coveredStepIds.contains(where: stepFilter.contains) }
    }

    var reviewQuestions: [ApiQuestion] {
        guard let bank else { return [] }
        return bank.questions.filter { bank.latestIsCorrect[$0.id] == false }
    }

    var overallRate: QuizFeature.AnswerRate? {
        rate(of: bank?.questions ?? [])
    }

    func stepStats(for stepID: ApiStep.ID) -> QuizFeature.StepStats {
        let questions = (bank?.questions ?? []).filter { $0.coveredStepIds.contains(stepID) }
        return QuizFeature.StepStats(questionCount: questions.count, rate: rate(of: questions))
    }

    private func rate(of questions: [ApiQuestion]) -> QuizFeature.AnswerRate? {
        let answers = questions.compactMap { bank?.latestIsCorrect[$0.id] }
        guard !answers.isEmpty else { return nil }
        return QuizFeature.AnswerRate(correctCount: answers.filter { $0 }.count, answeredCount: answers.count)
    }
}

extension QuizFeature.State {
    func quizContent(steps: [ApiStep]) -> QuizContent? {
        switch screen {
        case .start:
            nil
        case let .session(session):
            .question(session.questionContent(steps: steps))
        case let .result(result):
            .result(wrongStems: result.wrongQuestions.map(\.stem))
        }
    }
}

extension QuizFeature.Session {
    /// 回答した時点で1問分伸ばす（Web版と同じ）
    var progress: Double {
        let answeredCount = if case .answered = answer { index + 1 } else { index }
        return Double(answeredCount) / Double(questions.count)
    }

    fileprivate func questionContent(steps: [ApiStep]) -> QuizQuestionContent {
        let question = currentQuestion
        let choices = question.choices.enumerated().map { offset, choice in
            let (mark, badge) = mark(of: choice.id)
            return QuizChoiceContent(
                id: choice.id,
                label: Unicode.Scalar(UInt32(65 + offset)).map { String(Character($0)) } ?? "",
                markdown: choice.body,
                mark: mark,
                badge: badge
            )
        }
        let explanation: QuizExplanationContent? = if case let .answered(result) = answer {
            QuizExplanationContent(heading: "解説", markdown: result.explanation, relatedSteps: relatedSteps(of: question, steps: steps))
        } else {
            nil
        }
        return QuizQuestionContent(questionID: question.id, stem: question.stem, choices: choices, explanation: explanation)
    }

    private func mark(of choiceID: ApiChoice.ID) -> (QuizChoiceMark, String?) {
        switch answer {
        case let .selecting(selectedID?), let .grading(selectedID):
            return choiceID == selectedID ? (.selected, nil) : (.normal, nil)
        case .selecting(nil):
            return (.normal, nil)
        case let .answered(result):
            if choiceID == result.correctChoiceId { return (.correct, "正解") }
            if choiceID == result.selectedChoiceId { return (.yourAnswer, "あなたの回答") }
            return (.normal, nil)
        }
    }

    private func relatedSteps(of question: ApiQuestion, steps: [ApiStep]) -> String {
        let titles = question.coveredStepIds
            .map { id in steps.first { $0.id == id }?.title ?? "—" }
            .joined(separator: "、")
        return "関連ステップ：\(titles)" + (question.coveredStepIds.count > 1 ? "（横断設問）" : "")
    }
}
