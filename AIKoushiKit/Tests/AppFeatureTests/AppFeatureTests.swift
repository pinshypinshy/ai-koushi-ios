//
//  AppFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import APIClient
@testable import AppFeature
import ComposableArchitecture
import LoginFeature
import Models
import SidebarFeature
import Testing

@MainActor
struct AppFeatureTests {
    @Test(arguments: [[CourseSummary.mock("c1")], []])
    func bootstrapSucceeded_メイン画面を表示する(courses: [CourseSummary]) async {
        let response = BootstrapResponse.mock(courses: courses)
        let store = TestStore(initialState: AppFeature.State.launching) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { response }
        }

        await store.send(.task)
        await store.receive(\.bootstrapSucceeded) { $0 = .main(MainFeature.State(bootstrap: response)) }
    }

    @Test func bootstrapFailed_セッションが無ければ文言なしでログイン画面を表示する() async {
        let store = TestStore(initialState: AppFeature.State.launching) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw APIClientError.http(status: 401, body: nil) }
        }

        await store.send(.task)
        await store.receive(\.bootstrapFailed) { $0 = .login(LoginFeature.State()) }
    }

    @Test(arguments: [
        (APIClientError.network, AppFeature.LaunchError.network),
        (APIClientError.http(status: 500, body: nil), .other),
        (APIClientError.decoding, .other),
    ])
    func bootstrapFailed_結果ごとの起動エラーを表示する(error: APIClientError, expected: AppFeature.LaunchError) async {
        let store = TestStore(initialState: AppFeature.State.launching) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw error }
        }

        await store.send(.task)
        await store.receive(\.bootstrapFailed) { $0 = .launchFailed(expected) }
    }

    @Test func retryButtonTapped_起動し直してメイン画面を表示する() async {
        let response = BootstrapResponse.mock(courses: [.mock("c1")])
        let store = TestStore(initialState: AppFeature.State.launchFailed(.network)) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { response }
        }

        await store.send(.retryButtonTapped) { $0 = .launching }
        await store.receive(\.bootstrapSucceeded) { $0 = .main(MainFeature.State(bootstrap: response)) }
    }

    @Test func login_ログインしたらメイン画面を表示する() async {
        let response = BootstrapResponse.mock(courses: [.mock("c1")])
        let store = TestStore(initialState: AppFeature.State.login(LoginFeature.State(loginId: "guest-01", password: "pass"))) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in }
            $0.apiClient.bootstrap = { response }
        }
        // ログイン画面の中の状態の変化は LoginFeatureTests で確かめている
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.login(.loginButtonTapped))
        await store.receive(\.login.delegate.loggedIn)
        await store.receive(\.bootstrapSucceeded) { $0 = .main(MainFeature.State(bootstrap: response)) }
    }

    @Test func bootstrapFailed_ログイン直後の401ならログイン画面に戻す() async {
        let store = TestStore(initialState: AppFeature.State.login(LoginFeature.State(loginId: "guest-01", password: "pass"))) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in }
            $0.apiClient.bootstrap = { throw APIClientError.http(status: 401, body: nil) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.login(.loginButtonTapped))
        await store.receive(\.bootstrapFailed) { $0 = .login(LoginFeature.State()) }
    }

    @Test func main_セッション切れなら文言付きでログイン画面を表示する() async {
        let store = TestStore(initialState: AppFeature.State.main(MainFeature.State(bootstrap: .mock(courses: [.mock("c1")])))) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw APIClientError.http(status: 401, body: nil) }
        }

        await store.send(.main(.sidebar(.refreshPulled)))
        await store.receive(\.main.sidebar.refreshFailed)
        await store.receive(\.main.sidebar.delegate.sessionExpired)
        await store.receive(\.main.delegate.sessionExpired) {
            $0 = .login(LoginFeature.State(errorMessage: AppFeature.sessionExpiredMessage))
        }
    }

    @Test(arguments: [true, false])
    func logoutFinished_通信の成否によらずログイン画面を表示する(succeeds: Bool) async {
        let logoutCount = LockIsolated(0)
        let store = TestStore(initialState: AppFeature.State.main(MainFeature.State(bootstrap: .mock(courses: [.mock("c1")])))) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.logout = {
                logoutCount.withValue { $0 += 1 }
                if !succeeds { throw APIClientError.network }
            }
        }

        await store.send(.main(.sidebar(.logoutButtonTapped)))
        await store.receive(\.main.sidebar.delegate.logoutRequested)
        await store.receive(\.main.delegate.logoutRequested) { $0 = .loggingOut }
        await store.receive(\.logoutFinished) { $0 = .login(LoginFeature.State()) }
        #expect(logoutCount.value == 1)
    }

    @Test func main_ログアウトしたら取り直しの結果を捨てる() async {
        // 取り直しの応答を、ログアウトの後まで返さないため
        let (response, finishResponse) = AsyncStream.makeStream(of: Void.self)
        let store = TestStore(initialState: AppFeature.State.main(MainFeature.State(bootstrap: .mock(courses: [.mock("c1")])))) {
            AppFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = {
                for await _ in response { break }
                return .mock(courses: [.mock("c2")])
            }
            $0.apiClient.logout = {}
        }

        await store.send(.main(.sidebar(.refreshPulled)))
        await store.send(.main(.sidebar(.logoutButtonTapped)))
        await store.receive(\.main.sidebar.delegate.logoutRequested)
        await store.receive(\.main.delegate.logoutRequested) { $0 = .loggingOut }
        await store.receive(\.logoutFinished) { $0 = .login(LoginFeature.State()) }
        finishResponse.yield()
    }
}
