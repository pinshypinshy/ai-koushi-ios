//
//  QuizResultView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import ComposableArchitecture
import MarkdownWebView
import SharedUI
import SwiftUI

/// iSC-06 確認テスト／結果（§3.8）
struct QuizResultView: View {
    let store: StoreOf<QuizFeature>
    let result: QuizFeature.QuizResult
    let content: QuizContent
    let onScrollBoxTouch: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            summary
            if result.wrongQuestions.isEmpty {
                Spacer()
            } else {
                Text("誤答した問題")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                QuizWebView(
                    content: content,
                    onChoiceTap: { _ in },
                    onLinkTap: { store.send(.linkTapped($0)) },
                    onScrollBoxTouch: onScrollBoxTouch
                )
            }
            buttons
        }
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text(result.mode == .review ? "復習モード終了" : "テスト終了")
                .font(.subheadline)
                .foregroundStyle(AppColor.secondaryText)
            Text("\(result.rate.correctCount) / \(result.questionCount)")
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(AppColor.primaryText)
            Text("正答率 \(result.rate.percent)%")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(AppColor.secondaryText)
        }
        .padding()
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button {
                store.send(.reviewButtonTapped)
            } label: {
                Text("誤答のみ再挑戦（\(store.reviewQuestions.count)問）")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)
            .disabled(store.reviewQuestions.isEmpty)
            Button {
                store.send(.backToStartButtonTapped)
            } label: {
                Text("テスト一覧へ戻る")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appSecondary)
            Button {
                store.send(.lectureButtonTapped)
            } label: {
                Text("講義へ戻る")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appSecondary)
        }
        .padding()
    }
}
