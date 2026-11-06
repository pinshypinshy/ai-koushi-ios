//
//  MainFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import ComposableArchitecture
import CourseFeature
import Models
import SidebarFeature

@Reducer
public struct MainFeature {
    @ObservableState
    public struct State: Equatable {
        var sidebar: SidebarFeature.State
        var course: CourseFeature.State
        var isSidebarOpen = false

        init(bootstrap: BootstrapResponse) {
            self.sidebar = SidebarFeature.State(bootstrap: bootstrap)
            self.course = CourseFeature.State(courses: bootstrap.courses, selected: bootstrap.selected)
        }
    }

    public enum Action {
        case sidebar(SidebarFeature.Action)
        case course(CourseFeature.Action)
        case sidebarSwipedOpen
        case sidebarSwipedClosed
        case peekingMainTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case sessionExpired
            case logoutRequested
        }
    }

    public var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.sidebar, action: \.sidebar) { SidebarFeature() }
            Scope(state: \.course, action: \.course) { CourseFeature() }
            Reduce { state, action in
                switch action {
                case .course(.delegate(.sidebarRequested)), .sidebarSwipedOpen:
                    state.isSidebarOpen = true
                    return .none

                case .sidebar(.delegate(.courseSelected)), .sidebarSwipedClosed, .peekingMainTapped:
                    state.isSidebarOpen = false
                    return .none

                case .sidebar(.delegate(.sessionExpired)), .course(.delegate(.sessionExpired)):
                    return .send(.delegate(.sessionExpired))

                case .course(.delegate(.usageRefreshRequested)):
                    return .send(.sidebar(.usageRefreshRequested))

                case let .course(.delegate(.courseUpdated(course))):
                    return .send(.sidebar(.courseUpdated(course)))

                case .sidebar(.delegate(.logoutRequested)):
                    return .send(.delegate(.logoutRequested))

                case .sidebar, .course, .delegate:
                    return .none
                }
            }
        }
        // 講義の行を押したときも、取り直しで選択や講義の中身が変わったときも追従させる
        .onChange(of: { CourseListSnapshot(courses: $0.sidebar.courses, selectedCourseID: $0.sidebar.selectedCourseID) }) { _, snapshot in
            Reduce { _, _ in
                .send(.course(.coursesChanged(courses: snapshot.courses, selectedCourseID: snapshot.selectedCourseID)))
            }
        }
    }
}

private struct CourseListSnapshot: Equatable {
    let courses: [CourseSummary]
    let selectedCourseID: CourseSummary.ID?
}
