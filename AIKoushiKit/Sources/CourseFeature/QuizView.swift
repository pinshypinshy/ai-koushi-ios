//
//  QuizView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import ComposableArchitecture
import Models
import SharedUI
import SwiftUI

/// 確認テストのタブ（§3.6）
struct QuizView: View {
    let store: StoreOf<QuizFeature>
    let steps: [ApiStep]
    let quizStatus: QuizStatus
    var onScrollBoxTouch: (Bool) -> Void = { _ in }

    var body: some View {
        switch quizStatus {
        case .failed:
            ContentUnavailableView {
                Text("確認テストの生成に失敗しました")
            } description: {
                Text("講義はそのまま受講できます。")
            }
        case .pending:
            ContentUnavailableView {
                Text("確認テストを作成しています")
            } description: {
                Text("サイドバーの一覧を下に引っ張ると更新されます。")
            }
        case .ready:
            if store.bank == nil {
                notLoadedView
            } else {
                screenView
            }
        }
    }

    @ViewBuilder
    private var screenView: some View {
        switch store.screen {
        case .start:
            QuizStartView(store: store, steps: steps)
        case let .session(session):
            if let content = store.state.quizContent(steps: steps) {
                QuizSessionView(store: store, session: session, content: content, onScrollBoxTouch: onScrollBoxTouch)
            }
        case let .result(result):
            if let content = store.state.quizContent(steps: steps) {
                QuizResultView(store: store, result: result, content: content, onScrollBoxTouch: onScrollBoxTouch)
            }
        }
    }

    @ViewBuilder
    private var notLoadedView: some View {
        if let error = store.fetchError {
            ContentUnavailableView {
                Text(error.message)
                    .font(.body)
                    .foregroundStyle(AppColor.error)
            } actions: {
                if error.canRetry {
                    Button("再試行") {
                        store.send(.retryFetchButtonTapped)
                    }
                    .buttonStyle(.appSecondary)
                }
            }
        } else {
            ProgressView("確認テストを読み込んでいます")
        }
    }
}

#if DEBUG
#Preview("開始画面") {
    QuizView(store: .preview(latest: [.init(questionId: "q1", isCorrect: false)]), steps: .preview, quizStatus: .ready)
}

#Preview("出題") {
    QuizView(store: .preview(screen: .session(.init(mode: .review, questions: .preview, answer: .selecting("a")))), steps: .preview, quizStatus: .ready)
}

#Preview("回答後") {
    let result = AttemptResult(questionId: "q1", selectedChoiceId: "b", correctChoiceId: "a", isCorrect: false, explanation: "$AB$ の $(1,1)$ 成分は $1 \\cdot 5 + 2 \\cdot 7 = 19$ です。")
    QuizView(store: .preview(screen: .session(.init(mode: .normal, questions: .preview, answer: .answered(result)))), steps: .preview, quizStatus: .ready)
}

#Preview("結果") {
    QuizView(
        store: .preview(
            latest: [.init(questionId: "q1", isCorrect: false)],
            screen: .result(.init(mode: .normal, questionCount: 2, wrongQuestions: Array([ApiQuestion].preview.prefix(1))))
        ),
        steps: .preview,
        quizStatus: .ready
    )
}

#Preview("読み込み中") {
    QuizView(store: Store(initialState: QuizFeature.State(courseID: "c1")) { QuizFeature() }, steps: .preview, quizStatus: .ready)
}

#Preview("生成に失敗") {
    QuizView(store: .preview(), steps: .preview, quizStatus: .failed)
}

#Preview("作成中") {
    QuizView(store: .preview(), steps: .preview, quizStatus: .pending)
}

private extension Store<QuizFeature.State, QuizFeature.Action> {
    static func preview(latest: [AttemptSummary] = [], screen: QuizFeature.Screen = .start) -> Store {
        var state = QuizFeature.State(courseID: "c1")
        state.bank = .init(QuizResponse(questions: .preview, latestAttempts: latest))
        state.screen = screen
        return Store(initialState: state) { QuizFeature() }
    }
}

private extension [ApiQuestion] {
    static let preview: Self = [
        ApiQuestion(
            id: "q1",
            stem: "$A = \\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}$、$B = \\begin{pmatrix} 5 & 6 \\\\ 7 & 8 \\end{pmatrix}$ のとき、$AB$ の $(1,1)$ 成分はどれか。",
            choices: [
                ApiChoice(id: "a", body: "$19$"),
                ApiChoice(id: "b", body: "$22$"),
                ApiChoice(id: "c", body: "$43$"),
                ApiChoice(id: "d", body: "$50$"),
            ],
            coveredStepIds: ["s1", "s2"]
        ),
        ApiQuestion(id: "q2", stem: "問題2", choices: [ApiChoice(id: "a", body: "はい"), ApiChoice(id: "b", body: "いいえ")], coveredStepIds: ["s1"]),
    ]
}

private extension [ApiStep] {
    static let preview: Self = [
        ApiStep(id: "s1", orderIndex: 1, title: "ベクトル", status: .completed),
        ApiStep(id: "s2", orderIndex: 2, title: "行列", status: .inProgress),
        ApiStep(id: "s3", orderIndex: 3, title: "固有値", status: .notStarted),
    ]
}
#endif
