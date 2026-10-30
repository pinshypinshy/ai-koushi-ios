//
//  AppFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import APIClient
import ComposableArchitecture
import Foundation
import LoginFeature
import Models

@Reducer
public struct AppFeature {
    @CasePathable
    @dynamicMemberLookup
    @ObservableState
    public enum State: Equatable {
        case launching
        case launchFailed(LaunchError)
        case login(LoginFeature.State)
        case loggingOut
        case main(MainFeature.State)
    }

    public enum LaunchError: Equatable, Sendable {
        case network
        case other
    }

    public enum Action {
        case task
        case retryButtonTapped
        case bootstrapSucceeded(BootstrapResponse)
        case bootstrapFailed(any Error)
        case logoutFinished
        case login(LoginFeature.Action)
        case main(MainFeature.Action)
    }

    static let sessionExpiredMessage = "ログインの有効期限が切れました。もう一度ログインしてください。"

    private enum CancelID { case bootstrap }

    @Dependency(\.apiClient) var apiClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state = .launching
                return bootstrap()

            case .retryButtonTapped:
                state = .launching
                return bootstrap()

            // ログイン画面は送信中の表示のまま、bootstrap の結果を待つ（§4.2）
            case .login(.delegate(.loggedIn)):
                return bootstrap()

            case let .bootstrapSucceeded(response):
                state = .main(MainFeature.State(bootstrap: response))
                return .none

            case let .bootstrapFailed(error):
                switch error {
                case is CancellationError:
                    return .none
                case APIClientError.http(status: 401, body: _):
                    state = .login(LoginFeature.State())
                case APIClientError.network:
                    state = .launchFailed(.network)
                default:
                    state = .launchFailed(.other)
                }
                return .none

            case .main(.delegate(.sessionExpired)):
                state = .login(LoginFeature.State(errorMessage: Self.sessionExpiredMessage))
                return .none

            case .main(.delegate(.logoutRequested)):
                state = .loggingOut
                return .run { [apiClient] send in
                    do {
                        try await apiClient.logout()
                    } catch {
                        // 失敗してもログイン画面へ戻す（§4.5）。Cookie は logout の中で消えている
                    }
                    await send(.logoutFinished)
                }

            case .logoutFinished:
                state = .login(LoginFeature.State())
                return .none

            case .login, .main:
                return .none
            }
        }
        .ifCaseLet(\.login, action: \.login) { LoginFeature() }
        .ifCaseLet(\.main, action: \.main) { MainFeature() }
    }

    private func bootstrap() -> Effect<Action> {
        .run { [apiClient] send in
            do {
                await send(.bootstrapSucceeded(try await apiClient.bootstrap()))
            } catch {
                await send(.bootstrapFailed(error))
            }
        }
        .cancellable(id: CancelID.bootstrap, cancelInFlight: true)
    }
}
