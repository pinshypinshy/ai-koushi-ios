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
    // 指を離したら、開閉と同じアニメーションで元に戻す
    @GestureState(resetTransaction: Transaction(animation: Self.snapAnimation)) private var dragTranslation: CGFloat = 0

    private static let snapAnimation = Animation.snappy(duration: 0.2)
    // これより速く払ったら、ずれた量に関係なく払った向きに従う（§3.4）
    private static let flickVelocity: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = geometry.size.width * 0.8
            let offset = mainOffset(sidebarWidth: sidebarWidth)
            let progress = offset / sidebarWidth

            ZStack(alignment: .leading) {
                SidebarView(store: store.scope(state: \.sidebar, action: \.sidebar))
                    .frame(width: sidebarWidth)
                    .accessibilityHidden(!store.isSidebarOpen)

                CourseView(store: store.scope(state: \.course, action: \.course))
                    .allowsHitTesting(!store.isSidebarOpen)
                    .accessibilityHidden(store.isSidebarOpen)
                    .overlay {
                        if store.isSidebarOpen {
                            Color.clear
                                .contentShape(.rect)
                                .ignoresSafeArea()
                                .onTapGesture { store.send(.peekingMainTapped) }
                                .accessibilityLabel("サイドバーを閉じる")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    // ステータスバーの裏まで丸めるため、切り抜きの形も安全領域を越えさせる
                    .mask {
                        RoundedRectangle(cornerRadius: 40 * progress)
                            .ignoresSafeArea()
                    }
                    .shadow(radius: 8 * progress)
                    .offset(x: offset)
            }
            .simultaneousGesture(dragGesture(sidebarWidth: sidebarWidth))
        }
        .animation(Self.snapAnimation, value: store.isSidebarOpen)
        .sensoryFeedback(.impact(weight: .light), trigger: store.isSidebarOpen)
    }

    private func mainOffset(sidebarWidth: CGFloat) -> CGFloat {
        let base = store.isSidebarOpen ? sidebarWidth : 0
        return min(max(base + dragTranslation, 0), sidebarWidth)
    }

    private func dragGesture(sidebarWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragTranslation) { value, state, _ in
                // 縦の動きはサイドバーの一覧のスクロールに任せる
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let shouldOpen: Bool
                if abs(value.velocity.width) >= Self.flickVelocity {
                    shouldOpen = value.velocity.width > 0
                } else {
                    let base = store.isSidebarOpen ? sidebarWidth : 0
                    shouldOpen = base + value.translation.width > sidebarWidth / 2
                }
                guard shouldOpen != store.isSidebarOpen else { return }
                store.send(shouldOpen ? .sidebarSwipedOpen : .sidebarSwipedClosed)
            }
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
