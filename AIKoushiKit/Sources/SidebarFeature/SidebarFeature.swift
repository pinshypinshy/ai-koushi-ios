//
//  SidebarFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import APIClient
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct SidebarFeature {
    @ObservableState
    public struct State: Equatable {
        public internal(set) var user: ApiUser
        public internal(set) var courses: [CourseSummary]
        public internal(set) var usage: UsageSummary
        public internal(set) var selectedCourseID: CourseSummary.ID?
        var refreshErrorMessage: String?

        public var selectedCourse: CourseSummary? {
            courses.first { $0.id == selectedCourseID }
        }

        public init(bootstrap: BootstrapResponse) {
            self.user = bootstrap.user
            self.courses = bootstrap.courses
            self.usage = bootstrap.usage
            self.selectedCourseID = bootstrap.courses.first?.id
        }
    }

    public enum Action {
        case courseRowTapped(CourseSummary.ID)
        case refreshPulled
        case refreshSucceeded(BootstrapResponse)
        case refreshFailed(any Error)
        case logoutButtonTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case courseSelected
            case sessionExpired
            case logoutRequested
        }
    }

    static let networkErrorMessage = "通信できませんでした。ネットワーク接続を確認してください。"
    static let otherErrorMessage = "講義一覧を更新できませんでした。時間をおいて再度お試しください。"

    private enum CancelID { case refresh }

    @Dependency(\.apiClient) var apiClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .courseRowTapped(id):
                state.selectedCourseID = id
                return .send(.delegate(.courseSelected))

            case .refreshPulled:
                state.refreshErrorMessage = nil
                return .run { [apiClient] send in
                    do {
                        await send(.refreshSucceeded(try await apiClient.bootstrap()))
                    } catch {
                        await send(.refreshFailed(error))
                    }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)

            case let .refreshSucceeded(response):
                state.user = response.user
                state.courses = response.courses
                state.usage = response.usage
                if state.selectedCourse == nil {
                    state.selectedCourseID = response.courses.first?.id
                }
                return .none

            case let .refreshFailed(error):
                switch error {
                case is CancellationError:
                    return .none
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                case APIClientError.network:
                    state.refreshErrorMessage = Self.networkErrorMessage
                    return .none
                default:
                    state.refreshErrorMessage = Self.otherErrorMessage
                    return .none
                }

            case .logoutButtonTapped:
                return .send(.delegate(.logoutRequested))

            case .delegate:
                return .none
            }
        }
    }
}
