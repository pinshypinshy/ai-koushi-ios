//
//  MainView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import ComposableArchitecture
import CourseFeature
import Models
import SharedUI
import SidebarFeature
import SwiftUI

struct MainView: View {
    let store: StoreOf<MainFeature>

    var body: some View {
        ZStack(alignment: .leading) {
            CourseView(store: store.scope(state: \.course, action: \.course))

            if store.isSidebarOpen {
                AppColor.dimming
                    .ignoresSafeArea()
                    .onTapGesture { store.send(.dimmingTapped) }
                    .accessibilityLabel("サイドバーを閉じる")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)

                SidebarView(store: store.scope(state: \.sidebar, action: \.sidebar))
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.8 }
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.default, value: store.isSidebarOpen)
    }
}

#if DEBUG
#Preview("講義あり") {
    MainView(store: Store(initialState: MainFeature.State(bootstrap: .preview(courses: .preview))) { MainFeature() })
}

#Preview("サイドバーを開いた状態") {
    var state = MainFeature.State(bootstrap: .preview(courses: .preview))
    state.isSidebarOpen = true
    return MainView(store: Store(initialState: state) { MainFeature() })
}

#Preview("空状態") {
    MainView(store: Store(initialState: MainFeature.State(bootstrap: .preview(courses: []))) { MainFeature() })
}

extension BootstrapResponse {
    static func preview(courses: [CourseSummary]) -> Self {
        BootstrapResponse(
            user: ApiUser(id: "u1", email: "guest-01@example.com", displayName: "ゲスト01"),
            courses: courses,
            usage: UsageSummary(costUsd: 0.3, costLimitUsd: 1, courses: courses.count, courseLimit: 10, periodStart: 0)
        )
    }
}

extension [CourseSummary] {
    static let preview: Self = [
        CourseSummary(id: "c1", title: "線形代数の基礎", status: .ready, quizStatus: .ready, phase: nil, errorMessage: nil, totalSteps: 8, completedSteps: 3, updatedAt: 0),
        CourseSummary(id: "c2", title: "確率と統計", status: .generating, quizStatus: .pending, phase: .outline, errorMessage: nil, totalSteps: 0, completedSteps: 0, updatedAt: 0),
    ]
}
#endif
