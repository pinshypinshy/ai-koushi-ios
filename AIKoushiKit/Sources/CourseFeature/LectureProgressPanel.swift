//
//  LectureProgressPanel.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/06.
//

import ComposableArchitecture
import Models
import SharedUI
import SwiftUI

/// §3.2 の進捗パネル
struct LectureProgressPanel: View {
    let store: StoreOf<LectureFeature>

    private static let maxListHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            Button {
                store.send(.progressPanelTapped)
            } label: {
                HStack(spacing: 8) {
                    Text(store.progressTitle ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.footnote)
                        .foregroundStyle(AppColor.secondaryText)
                        .rotationEffect(store.isProgressExpanded ? .degrees(180) : .zero)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(store.isProgressExpanded ? "展開" : "折りたたみ")

            if store.isProgressExpanded, let steps = store.detail?.steps {
                ViewThatFits(in: .vertical) {
                    stepList(steps)
                    ScrollView { stepList(steps) }
                }
                .frame(maxHeight: Self.maxListHeight)
            }

            Divider()
        }
    }

    private func stepList(_ steps: [ApiStep]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(steps) { step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    stepIcon(step)
                        .frame(width: 16)
                    Text(step.title)
                        .font(.subheadline.weight(step.status == .inProgress ? .semibold : .regular))
                        .foregroundStyle(step.status == .notStarted ? AppColor.stepNotStarted : AppColor.primaryText)
                }
            }
            Text("\(store.completedStepCount) / \(steps.count) ステップ完了")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AppColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func stepIcon(_ step: ApiStep) -> some View {
        switch step.status {
        case .completed:
            Image(systemName: "checkmark")
                .foregroundStyle(AppColor.stepCompleted)
                .accessibilityLabel("完了")
        case .inProgress:
            Image(systemName: "circle.fill")
                .imageScale(.small)
                .foregroundStyle(AppColor.stepCurrent)
                .accessibilityLabel("現在のステップ")
        case .notStarted:
            Image(systemName: "circle")
                .imageScale(.small)
                .foregroundStyle(AppColor.stepNotStarted)
                .accessibilityLabel("未着手")
        }
    }
}
