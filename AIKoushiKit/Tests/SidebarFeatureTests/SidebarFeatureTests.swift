//
//  SidebarFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import APIClient
import ComposableArchitecture
import Models
@testable import SidebarFeature
import Testing

@MainActor
struct SidebarFeatureTests {
    @Test func init_最初の講義を選択する() {
        #expect(SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")])).selectedCourseID == "c1")
        #expect(SidebarFeature.State(bootstrap: .mock(courses: [])).selectedCourseID == nil)
    }

    @Test func courseRowTapped_講義を選択する() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))) {
            SidebarFeature()
        }

        await store.send(.courseRowTapped("c2")) { $0.selectedCourseID = "c2" }
        await store.receive(\.delegate.courseSelected)
    }

    @Test func refreshSucceeded_選択中の講義が残れば選択を保つ() async {
        var initial = SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.selectedCourseID = "c2"
        let response = BootstrapResponse.mock(
            displayName: "新しい名前",
            courses: [.mock("c0"), .mock("c1"), .mock("c2")],
            coursesUsed: 3
        )
        let store = TestStore(initialState: initial) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { response }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshSucceeded) {
            $0.user = response.user
            $0.courses = response.courses
            $0.usage = response.usage
        }
    }

    @Test func refreshSucceeded_選択中の講義が消えたら先頭を選択する() async {
        var initial = SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.selectedCourseID = "c2"
        let response = BootstrapResponse.mock(courses: [.mock("c1"), .mock("c3")])
        let store = TestStore(initialState: initial) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { response }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshSucceeded) {
            $0.courses = response.courses
            $0.selectedCourseID = "c1"
        }
    }

    @Test func refreshSucceeded_講義が無くなれば選択を外す() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { .mock(courses: []) }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshSucceeded) {
            $0.courses = []
            $0.selectedCourseID = nil
        }
    }

    @Test(arguments: [
        (APIClientError.network, SidebarFeature.networkErrorMessage),
        (APIClientError.http(status: 500, body: nil), SidebarFeature.otherErrorMessage),
        (APIClientError.decoding, SidebarFeature.otherErrorMessage),
    ])
    func refreshFailed_一覧を残して文言を表示する(error: APIClientError, message: String) async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw error }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshFailed) { $0.refreshErrorMessage = message }
    }

    @Test func refreshFailed_401ならセッション切れを親に知らせる() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw APIClientError.http(status: 401, body: nil) }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshFailed)
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func refreshPulled_前の文言を消す() async {
        var initial = SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))
        initial.refreshErrorMessage = SidebarFeature.networkErrorMessage
        let store = TestStore(initialState: initial) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { .mock(courses: [.mock("c1")]) }
        }

        await store.send(.refreshPulled) { $0.refreshErrorMessage = nil }
        await store.receive(\.refreshSucceeded)
    }

    @Test func usageRefreshRequested_利用状況を置き換える() async {
        let updated = UsageSummary(costUsd: 0.5, costLimitUsd: 1, courses: 2, courseLimit: 10, periodStart: 0)
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.usage = { updated }
        }

        await store.send(.usageRefreshRequested)
        await store.receive(\.usageRefreshSucceeded) { $0.usage = updated }
    }

    @Test func usageRefreshRequested_前の取り直しをやめる() async {
        let updated = UsageSummary(costUsd: 0.5, costLimitUsd: 1, courses: 2, courseLimit: 10, periodStart: 0)
        let calls = LockIsolated(0)
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.usage = {
                let call = calls.withValue { calls in
                    calls += 1
                    return calls
                }
                // やめられなければ、終わらない Effect が残ってテストが失敗する
                if call == 1 { try await Task.never() }
                return updated
            }
        }

        await store.send(.usageRefreshRequested)
        while calls.value == 0 { await Task.yield() }
        await store.send(.usageRefreshRequested)
        await store.receive(\.usageRefreshSucceeded) { $0.usage = updated }
    }

    @Test func usageRefreshFailed_401ならセッション切れを親に知らせる() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.usage = { throw APIClientError.http(status: 401, body: nil) }
        }

        await store.send(.usageRefreshRequested)
        await store.receive(\.usageRefreshFailed)
        await store.receive(\.delegate.sessionExpired)
    }

    @Test(arguments: [APIClientError.network, .http(status: 500, body: nil), .decoding])
    func usageRefreshFailed_その他は表示を残す(error: APIClientError) async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.usage = { throw error }
        }

        await store.send(.usageRefreshRequested)
        await store.receive(\.usageRefreshFailed)
    }

    @Test func courseUpdated_該当する行だけを置き換える() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))) {
            SidebarFeature()
        }

        await store.send(.courseUpdated(.mock("c2", completedSteps: 3))) {
            $0.courses = [.mock("c1"), .mock("c2", completedSteps: 3)]
        }
    }

    @Test func courseUpdated_一覧に無い講義は追加しない() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        }

        await store.send(.courseUpdated(.mock("c2")))
    }

    @Test func logoutButtonTapped_親にログアウトを頼む() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: []))) {
            SidebarFeature()
        }

        await store.send(.logoutButtonTapped)
        await store.receive(\.delegate.logoutRequested)
    }
}

extension BootstrapResponse {
    static func mock(displayName: String = "ゲスト01", courses: [CourseSummary], coursesUsed: Int = 1) -> Self {
        BootstrapResponse(
            user: ApiUser(id: "u1", email: "guest-01@example.com", displayName: displayName),
            courses: courses,
            selected: nil,
            usage: UsageSummary(costUsd: 0.1, costLimitUsd: 1, courses: coursesUsed, courseLimit: 10, periodStart: 0)
        )
    }
}

extension CourseSummary {
    static func mock(_ id: String, completedSteps: Int = 0) -> Self {
        CourseSummary(
            id: id, title: "講義 \(id)", status: .ready, quizStatus: .ready, phase: nil, errorMessage: nil,
            totalSteps: 5, completedSteps: completedSteps, updatedAt: 0
        )
    }
}
