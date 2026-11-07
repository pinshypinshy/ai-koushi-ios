//
//  CourseView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/29.
//

import ComposableArchitecture
import Models
import SharedUI
import SwiftUI

public struct CourseView: View {
    let store: StoreOf<CourseFeature>
    let isSidebarOpen: Bool
    let onScrollBoxTouch: (Bool) -> Void

    public init(
        store: StoreOf<CourseFeature>,
        isSidebarOpen: Bool = false,
        onScrollBoxTouch: @escaping (Bool) -> Void = { _ in }
    ) {
        self.store = store
        self.isSidebarOpen = isSidebarOpen
        self.onScrollBoxTouch = onScrollBoxTouch
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let id = store.selectedCourseID,
                   let itemStore = store.scope(state: \.items[id: id], action: \.items[id: id]) {
                    LectureView(store: itemStore.scope(state: \.lecture, action: \.lecture), isSidebarOpen: isSidebarOpen, onScrollBoxTouch: onScrollBoxTouch)
                } else {
                    ContentUnavailableView {
                        Text("まだ講義がありません")
                    } description: {
                        Text("講義は Web版で作成できます。作成した講義は、サイドバーの一覧を下に引っ張ると表示されます。")
                    } actions: {
                        Button("Web版を開く") {
                            store.send(.openWebButtonTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(store.selectedItem?.lecture.summary.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.menuButtonTapped)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("サイドバーを開く")
                }
            }
        }
        .task { store.send(.task) }
    }
}

#if DEBUG
#Preview("講義あり") {
    CourseView(store: Store(initialState: CourseFeature.State(courses: [.preview(status: .ready)], selected: nil)) { CourseFeature() })
}

#Preview("生成中") {
    CourseView(store: Store(initialState: CourseFeature.State(courses: [.preview(status: .generating)], selected: nil)) { CourseFeature() })
}

#Preview("生成失敗") {
    CourseView(store: Store(initialState: CourseFeature.State(courses: [.preview(status: .failed)], selected: nil)) { CourseFeature() })
}

#Preview("空状態") {
    CourseView(store: Store(initialState: CourseFeature.State(courses: [], selected: nil)) { CourseFeature() })
}

private extension CourseSummary {
    static func preview(status: CourseStatus) -> Self {
        CourseSummary(
            id: "c1", title: "線形代数の基礎", status: status, quizStatus: .pending, phase: nil, errorMessage: nil,
            totalSteps: status == .ready ? 8 : 0, completedSteps: status == .ready ? 3 : 0, updatedAt: 0
        )
    }
}
#endif
