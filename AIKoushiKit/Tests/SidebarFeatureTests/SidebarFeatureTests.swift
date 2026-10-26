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
    @Test func firstCourseIsSelectedInitially() {
        #expect(SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")])).selectedCourseID == "c1")
        #expect(SidebarFeature.State(bootstrap: .mock(courses: [])).selectedCourseID == nil)
    }

    @Test func tappingRowSelectsCourse() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))) {
            SidebarFeature()
        }

        await store.send(.courseRowTapped("c2")) { $0.selectedCourseID = "c2" }
        await store.receive(\.delegate.courseSelected)
    }

    @Test func refreshKeepsSelectionWhenCourseRemains() async {
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

    @Test func refreshSelectsFirstWhenSelectedCourseIsGone() async {
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

    @Test func refreshClearsSelectionWhenNoCoursesRemain() async {
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
    func failedRefreshKeepsListAndShowsMessage(error: APIClientError, message: String) async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw error }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshFailed) { $0.refreshErrorMessage = message }
    }

    @Test func unauthorizedRefreshReportsSessionExpired() async {
        let store = TestStore(initialState: SidebarFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            SidebarFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { throw APIClientError.http(status: 401, body: nil) }
        }

        await store.send(.refreshPulled)
        await store.receive(\.refreshFailed)
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func refreshClearsPreviousMessage() async {
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

    @Test func logoutIsRequestedFromUserMenu() async {
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
            usage: UsageSummary(costUsd: 0.1, costLimitUsd: 1, courses: coursesUsed, courseLimit: 10, periodStart: 0)
        )
    }
}

extension CourseSummary {
    static func mock(_ id: String) -> Self {
        CourseSummary(
            id: id, title: "講義 \(id)", status: .ready, quizStatus: .ready, phase: nil, errorMessage: nil,
            totalSteps: 5, completedSteps: 0, updatedAt: 0
        )
    }
}
