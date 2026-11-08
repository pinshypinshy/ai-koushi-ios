//
//  LectureActionArea.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/06.
//

import ComposableArchitecture
import SharedUI
import SwiftUI

/// §3.2 の操作の領域。何も出さないときは高さを取らない
struct LectureActionArea: View {
    let store: StoreOf<LectureFeature>

    var body: some View {
        VStack(spacing: 0) {
            if let message = store.visibleStreamError {
                errorText(message)
            }
            if store.canRegenerate {
                Button {
                    store.send(.regenerateButtonTapped)
                } label: {
                    Text("再生成する")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appSecondary)
                .padding(.top, 8)
            }
            if store.isAllStepsCompleted {
                VStack(spacing: 2) {
                    Text("全ステップが完了しました")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.primaryText)
                    Text("まだわからないことがあれば、いつでも質問してください")
                        .font(.footnote)
                        .foregroundStyle(AppColor.secondaryText)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                Button {
                    store.send(.quizButtonTapped)
                } label: {
                    Text("確認テストへ")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appSecondary)
                .padding(.top, 8)
            }
            if store.showsCompleteStepButton {
                Button {
                    store.send(.completeStepButtonTapped)
                } label: {
                    Text(completeStepTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
                .disabled(!store.canCompleteStep)
                .padding(.top, 8)
            }
            if let message = store.stepCompletionErrorMessage {
                errorText(message)
            }
        }
        .padding(.horizontal)
    }

    private var completeStepTitle: String {
        if store.isCompletingStep { return "要約を作成しています" }
        return store.isLastStep ? "講義を終える" : "次のステップへ進む"
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(AppColor.error)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}
