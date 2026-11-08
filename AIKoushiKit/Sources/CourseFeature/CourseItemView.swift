//
//  CourseItemView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import ComposableArchitecture
import Models
import SwiftUI

struct CourseItemView: View {
    let store: StoreOf<CourseItemFeature>
    let isSidebarOpen: Bool
    let onScrollBoxTouch: (Bool) -> Void
    let onMenuTap: () -> Void

    var body: some View {
        TabView(selection: Binding(get: { store.displayedTab }, set: { store.send(.tabSelected($0)) })) {
            NavigationStack {
                LectureView(
                    store: store.scope(state: \.lecture, action: \.lecture),
                    isSidebarOpen: isSidebarOpen,
                    onScrollBoxTouch: onScrollBoxTouch
                )
                .courseToolbar(title: title, onMenuTap: onMenuTap)
                .toolbar(store.showsTabBar ? .visible : .hidden, for: .tabBar)
            }
            .tabItem { Label("講義", systemImage: "text.bubble") }
            .tag(CourseItemFeature.Tab.lecture)

            NavigationStack {
                QuizView(
                    store: store.scope(state: \.quiz, action: \.quiz),
                    steps: store.lecture.detail?.steps ?? [],
                    quizStatus: store.quizStatus
                )
                .courseToolbar(title: title, onMenuTap: onMenuTap)
                .toolbar(store.showsTabBar ? .visible : .hidden, for: .tabBar)
            }
            .tabItem { Label("確認テスト", systemImage: "checkmark.square") }
            .tag(CourseItemFeature.Tab.quiz)
        }
    }

    private var title: String {
        store.lecture.summary.title
    }
}
