//
//  QuizSessionView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import ComposableArchitecture
import MarkdownWebView
import SharedUI
import SwiftUI

/// iSC-05 確認テスト／出題（§3.7）
struct QuizSessionView: View {
    let store: StoreOf<QuizFeature>
    let session: QuizFeature.Session
    let content: QuizContent
    let onScrollBoxTouch: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            QuizWebView(
                content: content,
                onChoiceTap: { store.send(.choiceTapped($0)) },
                onLinkTap: { store.send(.linkTapped($0)) },
                onScrollBoxTouch: onScrollBoxTouch
            )
            actionArea
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if session.mode == .review {
                    Text("復習モード")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.reviewMode)
                }
                Text("第 \(session.index + 1) 問 / 全 \(session.questions.count) 問")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(AppColor.secondaryText)
            }
            ProgressView(value: session.progress)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var actionArea: some View {
        VStack(spacing: 8) {
            if let message = session.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppColor.error)
                    .multilineTextAlignment(.center)
            }
            primaryButton
            Button {
                store.send(.quitButtonTapped)
            } label: {
                Text("テストをやめる")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isGrading)
        }
        .padding()
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch session.answer {
        case let .selecting(choiceID):
            prominentButton("回答する") { store.send(.submitButtonTapped) }
                .disabled(choiceID == nil)
        case .grading:
            prominentButton("採点しています") {}
                .disabled(true)
        case .answered:
            prominentButton(session.isLastQuestion ? "結果を見る" : "次の問題へ") { store.send(.nextButtonTapped) }
        }
    }

    private func prominentButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var isGrading: Bool {
        if case .grading = session.answer { true } else { false }
    }
}
