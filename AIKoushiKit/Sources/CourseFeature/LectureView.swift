//
//  LectureView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/06.
//

import ComposableArchitecture
import MarkdownWebView
import Models
import SharedUI
import SwiftUI

struct LectureView: View {
    let store: StoreOf<LectureFeature>
    var isSidebarOpen = false
    var onScrollBoxTouch: (Bool) -> Void = { _ in }
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if store.isFetching {
                ProgressView()
                    .padding(.vertical, 8)
            }
            if let error = store.fetchError {
                fetchErrorView(error)
            }

            if store.displayedStatus != .ready {
                Spacer()
                CourseStatusLabel(course: store.detail?.summary ?? store.summary)
                Spacer()
            } else if store.detail != nil {
                LectureProgressPanel(store: store)
                    .simultaneousGesture(closeKeyboardGesture)
                LectureConversation(store: store, onScrollBoxTouch: onScrollBoxTouch)
                LectureActionArea(store: store)
                    .simultaneousGesture(closeKeyboardGesture)
                LectureInputBar(store: store, isFocused: $isInputFocused)
            } else {
                Spacer()
            }
        }
        .onChange(of: isSidebarOpen) { _, isOpen in
            // フォーカスを残すと、サイドバーを閉じたときにキーボードが開き直す（§3.2）
            if isOpen { isInputFocused = false }
        }
    }

    private var closeKeyboardGesture: some Gesture {
        TapGesture().onEnded { isInputFocused = false }
    }

    private func fetchErrorView(_ error: LectureFeature.FetchError) -> some View {
        VStack(spacing: 8) {
            Text(error.message)
                .font(.footnote)
                .foregroundStyle(AppColor.error)
                .multilineTextAlignment(.center)
            if error.canRetry {
                Button("再試行") {
                    store.send(.retryFetchButtonTapped)
                }
                .buttonStyle(.appSecondary)
            }
        }
        .padding()
    }
}

/// 文字が届くたびに、この部品だけを描き直す
private struct LectureConversation: View {
    let store: StoreOf<LectureFeature>
    let onScrollBoxTouch: (Bool) -> Void

    var body: some View {
        if let content = store.conversationContent {
            ConversationWebView(
                content: content,
                onLinkTap: { store.send(.linkTapped($0)) },
                onScrollBoxTouch: onScrollBoxTouch
            )
        }
    }
}

#if DEBUG
#Preview("受信中") {
    LectureView(store: .preview(activity: .streaming(text: "行列の積は", replacingMessageID: nil)))
}

#Preview("待機中") {
    LectureView(store: .preview())
}

#Preview("受信の失敗") {
    LectureView(store: .preview(streamErrorMessage: "応答を取得できませんでした。時間をおいて再度お試しください。"))
}

#Preview("完了待ち") {
    LectureView(store: .preview(activity: .completingStep))
}

#Preview("全ステップ完了") {
    LectureView(store: .preview(currentStepId: nil))
}

#Preview("取得のエラー") {
    LectureView(store: Store(initialState: {
        var state = LectureFeature.State(summary: .preview(status: .ready))
        state.fetchError = .network
        return state
    }()) { LectureFeature() })
}

#Preview("生成中") {
    LectureView(store: Store(initialState: LectureFeature.State(summary: .preview(status: .generating))) { LectureFeature() })
}

private extension Store<LectureFeature.State, LectureFeature.Action> {
    static func preview(
        currentStepId: String? = "s2",
        activity: LectureFeature.Activity = .idle,
        streamErrorMessage: String? = nil
    ) -> Store {
        var state = LectureFeature.State(
            summary: .preview(status: .ready),
            detail: CourseDetail(
                summary: .preview(status: .ready),
                currentStepId: currentStepId,
                steps: [
                    ApiStep(id: "s1", orderIndex: 1, title: "ベクトル", status: .completed),
                    ApiStep(id: "s2", orderIndex: 2, title: "行列", status: currentStepId == nil ? .completed : .inProgress),
                    ApiStep(id: "s3", orderIndex: 3, title: "固有値", status: currentStepId == nil ? .completed : .notStarted),
                ],
                messages: [
                    ApiMessage(id: "m1", stepId: "s2", role: .assistant, content: "行列 $A$ と $B$ の積を考えます。", interrupted: false),
                    ApiMessage(id: "m2", stepId: "s2", role: .user, content: "順番を変えても同じですか？", interrupted: false),
                    ApiMessage(id: "m3", stepId: "s2", role: .assistant, content: "一般に $AB \\neq BA$ です。", interrupted: false),
                ]
            )
        )
        state.activity = activity
        state.streamErrorMessage = streamErrorMessage
        return Store(initialState: state) { LectureFeature() }
    }
}

private extension CourseSummary {
    static func preview(status: CourseStatus) -> Self {
        CourseSummary(
            id: "c1", title: "線形代数の基礎", status: status, quizStatus: .pending, phase: nil, errorMessage: nil,
            totalSteps: status == .ready ? 3 : 0, completedSteps: status == .ready ? 1 : 0, updatedAt: 0
        )
    }
}
#endif
