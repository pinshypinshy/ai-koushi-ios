//
//  CourseFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/29.
//

import AppConfig
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct CourseFeature {
    @ObservableState
    public struct State: Equatable {
        public var course: CourseSummary?

        public init(course: CourseSummary?) {
            self.course = course
        }
    }

    public enum Action {
        case menuButtonTapped
        case openWebButtonTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case sidebarRequested
        }
    }

    @Dependency(\.openURL) var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .menuButtonTapped:
                return .send(.delegate(.sidebarRequested))

            case .openWebButtonTapped:
                return .run { [openURL] _ in
                    await openURL(ServerURL.production)
                }

            case .delegate:
                return .none
            }
        }
    }
}
