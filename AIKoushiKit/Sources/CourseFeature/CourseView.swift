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

    public init(store: StoreOf<CourseFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let course = store.course {
                    VStack(spacing: 8) {
                        Text(course.title)
                            .font(.title2.bold())
                            .foregroundStyle(AppColor.primaryText)
                            .multilineTextAlignment(.center)
                        CourseStatusLabel(course: course)
                    }
                    .padding()
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
    }
}

#Preview("講義あり") {
    CourseView(store: Store(initialState: CourseFeature.State(course: .preview(status: .ready))) { CourseFeature() })
}

#Preview("生成中") {
    CourseView(store: Store(initialState: CourseFeature.State(course: .preview(status: .generating))) { CourseFeature() })
}

#Preview("生成失敗") {
    CourseView(store: Store(initialState: CourseFeature.State(course: .preview(status: .failed))) { CourseFeature() })
}

#Preview("空状態") {
    CourseView(store: Store(initialState: CourseFeature.State(course: nil)) { CourseFeature() })
}

private extension CourseSummary {
    static func preview(status: CourseStatus) -> Self {
        CourseSummary(
            id: "c1", title: "線形代数の基礎", status: status, quizStatus: .pending, phase: nil, errorMessage: nil,
            totalSteps: status == .ready ? 8 : 0, completedSteps: status == .ready ? 3 : 0, updatedAt: 0
        )
    }
}
