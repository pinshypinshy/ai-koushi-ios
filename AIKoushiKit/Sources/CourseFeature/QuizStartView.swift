//
//  QuizStartView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import ComposableArchitecture
import Models
import SharedUI
import SwiftUI

/// iSC-04 確認テスト／開始（§3.6）
struct QuizStartView: View {
    let store: StoreOf<QuizFeature>
    let steps: [ApiStep]

    var body: some View {
        List {
            if let error = store.fetchError {
                Section {
                    Text(error.message)
                        .font(.footnote)
                        .foregroundStyle(AppColor.error)
                    if error.canRetry {
                        Button("再試行") {
                            store.send(.retryFetchButtonTapped)
                        }
                    }
                }
            }

            Section {
                LabeledContent("出題数") {
                    Text("\(store.filteredQuestions.count) 問")
                        .monospacedDigit()
                }
                LabeledContent("正答率") {
                    Text(Self.rateText(store.overallRate))
                        .monospacedDigit()
                }
                Button {
                    store.send(.startButtonTapped)
                } label: {
                    Text("テストを始める")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
                .disabled(store.filteredQuestions.isEmpty)
            }

            Section {
                ForEach(steps) { step in
                    stepRow(step)
                }
            } header: {
                Text("ステップで絞り込む（任意）")
            } footer: {
                Text("設問はステップに1対1で対応しません。複数ステップにまたがる横断設問があるため、各行の合計は総問数と一致しないことがあります。")
            }

            Section {
                Button {
                    store.send(.reviewButtonTapped)
                } label: {
                    Text("誤答のみに取り組む（\(store.reviewQuestions.count)問）")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appSecondary)
                .disabled(store.reviewQuestions.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func stepRow(_ step: ApiStep) -> some View {
        let isSelected = store.stepFilter.contains(step.id)
        let stats = store.state.stepStats(for: step.id)
        return Button {
            store.send(.stepFilterToggled(step.id))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppColor.checkOn : AppColor.checkOff)
                Text(step.title)
                    .foregroundStyle(AppColor.primaryText)
                Spacer()
                Text(Self.statsText(stats))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppColor.secondaryText)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func rateText(_ rate: QuizFeature.AnswerRate?) -> String {
        guard let rate else { return "—" }
        return "\(rate.percent)%（\(rate.correctCount) / \(rate.answeredCount)）"
    }

    private static func statsText(_ stats: QuizFeature.StepStats) -> String {
        guard let rate = stats.rate else { return "\(stats.questionCount)問" }
        return "\(stats.questionCount)問 / 正答率 \(rate.percent)%"
    }
}
