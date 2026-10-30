//
//  MainFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import APIClient
@testable import AppFeature
import ComposableArchitecture
import CourseFeature
import Models
import SidebarFeature
import Testing

// Sidebar の中の状態の変化は SidebarFeatureTests で確かめているため、ここではメイン画面側だけを確かめる
@MainActor
struct MainFeatureTests {
    @Test func courseShowsFirstCourseInitially() {
        #expect(MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")])).course.course?.id == "c1")
        #expect(MainFeature.State(bootstrap: .mock(courses: [])).course.course == nil)
    }

    @Test func menuButtonOpensSidebar() async {
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        }

        await store.send(.course(.menuButtonTapped))
        await store.receive(\.course.delegate.sidebarRequested) { $0.isSidebarOpen = true }
    }

    @Test func tappingRowShowsCourseAndClosesSidebar() async {
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.isSidebarOpen = true
        let store = TestStore(initialState: initial) {
            MainFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sidebar(.courseRowTapped("c2"))) {
            $0.course.course = .mock("c2")
        }
        await store.receive(\.sidebar.delegate.courseSelected) { $0.isSidebarOpen = false }
    }

    @Test func tappingPeekingMainClosesSidebarWithoutChangingSelection() async {
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.isSidebarOpen = true
        let store = TestStore(initialState: initial) {
            MainFeature()
        }

        await store.send(.peekingMainTapped) { $0.isSidebarOpen = false }
    }

    @Test func swipesOpenAndCloseSidebar() async {
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        }

        await store.send(.sidebarSwipedOpen) { $0.isSidebarOpen = true }
        await store.send(.sidebarSwipedClosed) { $0.isSidebarOpen = false }
    }

    @Test func courseFollowsRefreshedSelection() async {
        let updated = CourseSummary.mock("c1", completedSteps: 3)
        let response = BootstrapResponse.mock(courses: [updated])
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { response }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sidebar(.refreshPulled))
        await store.receive(\.sidebar.refreshSucceeded) {
            $0.course.course = updated
        }
    }

    @Test func courseBecomesEmptyWhenNoCoursesRemain() async {
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { .mock(courses: []) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sidebar(.refreshPulled))
        await store.receive(\.sidebar.refreshSucceeded) {
            $0.course.course = nil
        }
    }
}

extension BootstrapResponse {
    static func mock(courses: [CourseSummary]) -> Self {
        BootstrapResponse(
            user: ApiUser(id: "u1", email: "guest-01@example.com", displayName: "ゲスト01"),
            courses: courses,
            usage: UsageSummary(costUsd: 0.1, costLimitUsd: 1, courses: courses.count, courseLimit: 10, periodStart: 0)
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
