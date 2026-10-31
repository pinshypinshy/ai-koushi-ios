//
//  LoginFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import APIClient
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct LoginFeature {
    @ObservableState
    public struct State: Equatable {
        var loginId: String
        var password: String
        var isGuestFormOpen = false
        var isSubmitting = false
        var errorMessage: String?

        var canSubmit: Bool { !loginId.isEmpty && !password.isEmpty && !isSubmitting }

        public init(loginId: String = "", password: String = "", errorMessage: String? = nil) {
            self.loginId = loginId
            self.password = password
            self.errorMessage = errorMessage
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case guestSignInButtonTapped
        case loginButtonTapped
        case loginSucceeded
        case loginFailed(any Error)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case loggedIn
        }
    }

    static let networkErrorMessage = "通信できませんでした。ネットワーク接続を確認してください。"
    static let otherErrorMessage = "ログインできませんでした。時間をおいて再度お試しください。"

    @Dependency(\.apiClient) var apiClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .guestSignInButtonTapped:
                state.isGuestFormOpen = true
                return .none

            case .loginButtonTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.errorMessage = nil
                let loginId = state.loginId
                let password = state.password
                return .run { [apiClient] send in
                    do {
                        try await apiClient.guestLogin(loginId: loginId, password: password)
                        await send(.loginSucceeded)
                    } catch {
                        await send(.loginFailed(error))
                    }
                }

            // 成功時は isSubmitting を戻さない。AppFeature が画面を切り替えるまで再送信させないため
            case .loginSucceeded:
                return .send(.delegate(.loggedIn))

            case let .loginFailed(error):
                state.isSubmitting = false
                if error is CancellationError { return .none }
                state.password = ""
                state.errorMessage = Self.message(for: error)
                return .none

            case .delegate:
                return .none
            }
        }
    }

    static func message(for error: any Error) -> String {
        switch error as? APIClientError {
        case .http(status: 400, body: let body?), .http(status: 401, body: let body?), .http(status: 429, body: let body?):
            return body.message
        case .network:
            return networkErrorMessage
        default:
            return otherErrorMessage
        }
    }
}
