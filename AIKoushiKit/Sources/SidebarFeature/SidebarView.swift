//
//  SidebarView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import ComposableArchitecture
import Models
import SharedUI
import SwiftUI

public struct SidebarView: View {
    let store: StoreOf<SidebarFeature>

    public init(store: StoreOf<SidebarFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text("AI講師")
                .font(.title2.bold())
                .foregroundStyle(AppColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isHeader)

            // 0件のときも引っ張って取り直せるよう、案内文も List の中に置く
            List {
                if let message = store.refreshErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppColor.error)
                        .listRowBackground(Color.clear)
                        .listRowInsets(Self.rowInsets)
                        .listRowSeparator(.hidden)
                }
                if store.courses.isEmpty {
                    Text("講義はまだありません")
                        .foregroundStyle(AppColor.secondaryText)
                        .listRowBackground(Color.clear)
                        .listRowInsets(Self.rowInsets)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(store.courses) { course in
                        courseRow(course)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                await store.send(.refreshPulled).finish()
            }

            Divider()
            UsageMeterView(usage: store.usage)
                .padding(.horizontal, 20)
                .padding(.vertical)

            Divider()
            userMenu
                .padding(.horizontal, 20)
                .padding(.vertical)
        }
        .background(AppColor.sidebarBackground)
    }

    private func courseRow(_ course: CourseSummary) -> some View {
        Button {
            store.send(.courseRowTapped(course.id))
        } label: {
            HStack {
                Text(course.title)
                    .lineLimit(1)
                    .foregroundStyle(AppColor.primaryText)
                Spacer()
                CourseStatusLabel(course: course)
            }
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(course.id == store.selectedCourseID ? AppColor.selectedRowBackground : Color.clear)
                .padding(.horizontal, 8)
        )
        .listRowInsets(Self.rowInsets)
        .listRowSeparator(.hidden)
    }

    private static let rowInsets = EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

    private var userMenu: some View {
        Menu {
            Section {
                Button("ログアウト") {
                    store.send(.logoutButtonTapped)
                }
            } header: {
                Text("\(store.user.displayName)\n\(store.user.email)")
            }
        } label: {
            Label {
                Text(store.user.displayName)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "person.circle")
            }
            .foregroundStyle(AppColor.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("講義あり") {
    SidebarView(store: Store(initialState: SidebarFeature.State(bootstrap: .preview(courses: .preview, costUsd: 0.85))) {
        SidebarFeature()
    })
}

#Preview("0件・上限") {
    SidebarView(store: Store(initialState: SidebarFeature.State(bootstrap: .preview(courses: [], costUsd: 1.2))) {
        SidebarFeature()
    })
}

#Preview("取り直しの失敗") {
    var state = SidebarFeature.State(bootstrap: .preview(courses: .preview, costUsd: 0.1))
    state.refreshErrorMessage = SidebarFeature.networkErrorMessage
    return SidebarView(store: Store(initialState: state) { SidebarFeature() })
}

private extension BootstrapResponse {
    static func preview(courses: [CourseSummary], costUsd: Double) -> Self {
        BootstrapResponse(
            user: ApiUser(id: "u1", email: "guest-01@example.com", displayName: "ゲスト01"),
            courses: courses,
            usage: UsageSummary(costUsd: costUsd, costLimitUsd: 1, courses: courses.count, courseLimit: 10, periodStart: 0)
        )
    }
}

private extension [CourseSummary] {
    static let preview: Self = [
        CourseSummary(id: "c1", title: "線形代数の基礎", status: .ready, quizStatus: .ready, phase: nil, errorMessage: nil, totalSteps: 8, completedSteps: 3, updatedAt: 0),
        CourseSummary(id: "c2", title: "確率と統計", status: .generating, quizStatus: .pending, phase: .outline, errorMessage: nil, totalSteps: 0, completedSteps: 0, updatedAt: 0),
        CourseSummary(id: "c3", title: "微分方程式", status: .failed, quizStatus: .failed, phase: nil, errorMessage: "生成に失敗", totalSteps: 0, completedSteps: 0, updatedAt: 0),
    ]
}
#endif
