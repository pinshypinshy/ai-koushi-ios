//
//  LoginFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import APIClient
import ComposableArchitecture
@testable import LoginFeature
import Models
import Testing

@MainActor
struct LoginFeatureTests {
    @Test func loginSucceeded_親にログインを知らせる() async {
        let store = TestStore(initialState: LoginFeature.State(loginId: "guest-01", password: "pass")) {
            LoginFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in }
        }

        await store.send(.loginButtonTapped) { $0.isSubmitting = true }
        await store.receive(\.loginSucceeded)
        await store.receive(\.delegate.loggedIn)
    }

    @Test(arguments: [400, 401, 429])
    func loginFailed_サーバーの文言を表示してパスワードを消す(status: Int) async {
        let store = TestStore(initialState: LoginFeature.State(loginId: "guest-01", password: "pass")) {
            LoginFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in
                throw APIClientError.http(status: status, body: ApiError(error: "e", message: "サーバーの文言"))
            }
        }

        await store.send(.loginButtonTapped) { $0.isSubmitting = true }
        await store.receive(\.loginFailed) {
            $0.isSubmitting = false
            $0.password = ""
            $0.errorMessage = "サーバーの文言"
        }
    }

    @Test func loginFailed_通信エラーは固定の文言を表示する() async {
        let store = TestStore(initialState: LoginFeature.State(loginId: "guest-01", password: "pass")) {
            LoginFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in throw APIClientError.network }
        }

        await store.send(.loginButtonTapped) { $0.isSubmitting = true }
        await store.receive(\.loginFailed) {
            $0.isSubmitting = false
            $0.password = ""
            $0.errorMessage = LoginFeature.networkErrorMessage
        }
    }

    @Test(arguments: [
        APIClientError.http(status: 500, body: nil),
        APIClientError.http(status: 401, body: nil),
        APIClientError.decoding,
    ])
    func loginFailed_その他のエラーは固定の文言を表示する(error: APIClientError) async {
        let store = TestStore(initialState: LoginFeature.State(loginId: "guest-01", password: "pass")) {
            LoginFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in throw error }
        }

        await store.send(.loginButtonTapped) { $0.isSubmitting = true }
        await store.receive(\.loginFailed) {
            $0.isSubmitting = false
            $0.password = ""
            $0.errorMessage = LoginFeature.otherErrorMessage
        }
    }

    @Test func loginButtonTapped_送信中は2回目を送らない() async {
        let callCount = LockIsolated(0)
        // 1回目の通信を、2回目のタップの後まで終わらせないため
        let (response, finishResponse) = AsyncStream.makeStream(of: Void.self)
        let store = TestStore(initialState: LoginFeature.State(loginId: "guest-01", password: "pass")) {
            LoginFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in
                callCount.withValue { $0 += 1 }
                for await _ in response { break }
            }
        }

        await store.send(.loginButtonTapped) { $0.isSubmitting = true }
        await store.send(.loginButtonTapped)
        finishResponse.yield()
        await store.receive(\.loginSucceeded)
        await store.receive(\.delegate.loggedIn)
        #expect(callCount.value == 1)
    }

    @Test(arguments: [("", "pass"), ("guest-01", "")])
    func loginButtonTapped_空の欄があれば送らない(loginId: String, password: String) async {
        // guestLogin を差し替えていないため、呼ばれればテストが失敗する
        let store = TestStore(initialState: LoginFeature.State(loginId: loginId, password: password)) {
            LoginFeature()
        }

        await store.send(.loginButtonTapped)
    }

    @Test func loginButtonTapped_前の文言を消す() async {
        let store = TestStore(
            initialState: LoginFeature.State(loginId: "guest-01", password: "pass", errorMessage: "ログインの有効期限が切れました。")
        ) {
            LoginFeature()
        } withDependencies: {
            $0.apiClient.guestLogin = { _, _ in }
        }

        await store.send(.loginButtonTapped) {
            $0.isSubmitting = true
            $0.errorMessage = nil
        }
        await store.receive(\.loginSucceeded)
        await store.receive(\.delegate.loggedIn)
    }

    @Test func guestSignInButtonTapped_フォームを開く() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        await store.send(.guestSignInButtonTapped) { $0.isGuestFormOpen = true }
    }
}
