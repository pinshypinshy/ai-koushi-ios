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
            let sidebar = SidebarFeature.State(bootstrap: bootstrap)
            self.sidebar = sidebar
            self.course = CourseFeature.State(course: sidebar.selectedCourse)
        }
    }

    public enum Action {
        case sidebar(SidebarFeature.Action)
        case course(CourseFeature.Action)
        case dimmingTapped
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
                case .course(.delegate(.sidebarRequested)):
                    state.isSidebarOpen = true
                    return .none

                case .sidebar(.delegate(.courseSelected)), .dimmingTapped:
                    state.isSidebarOpen = false
                    return .none

                case .sidebar(.delegate(.sessionExpired)):
                    return .send(.delegate(.sessionExpired))

                case .sidebar(.delegate(.logoutRequested)):
                    return .send(.delegate(.logoutRequested))

                case .sidebar, .course, .delegate:
                    return .none
                }
            }
        }
        // 講義の行を押したときも、取り直しで選択や講義の中身が変わったときも追従させる
        .onChange(of: \.sidebar.selectedCourse) { _, selectedCourse in
            Reduce { state, _ in
                state.course.course = selectedCourse
                return .none
            }
        }
    }
}
