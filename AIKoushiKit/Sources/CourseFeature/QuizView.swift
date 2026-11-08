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
            } else if store.screen == .start {
                QuizStartView(store: store, steps: steps)
            } else {
                // 出題と結果の画面は WebView と一緒に作る（ADR 0007）
                Color.clear
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
                    .buttonStyle(.bordered)
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
    static func preview(latest: [AttemptSummary] = []) -> Store {
        var state = QuizFeature.State(courseID: "c1")
        state.bank = .init(
            QuizResponse(
                questions: [
                    ApiQuestion(id: "q1", stem: "問題1", choices: [], coveredStepIds: ["s1"]),
                    ApiQuestion(id: "q2", stem: "問題2", choices: [], coveredStepIds: ["s1", "s2"]),
                ],
                latestAttempts: latest
            )
        )
        return Store(initialState: state) { QuizFeature() }
    }
}

private extension [ApiStep] {
    static let preview: Self = [
        ApiStep(id: "s1", orderIndex: 1, title: "ベクトル", status: .completed),
        ApiStep(id: "s2", orderIndex: 2, title: "行列", status: .inProgress),
        ApiStep(id: "s3", orderIndex: 3, title: "固有値", status: .notStarted),
    ]
}
#endif
