//
//  MainFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import APIClient
@testable import AppFeature
import ComposableArchitecture
@testable import CourseFeature
import Models
@testable import SidebarFeature
import Testing

// Sidebar の中の状態の変化は SidebarFeatureTests で確かめているため、ここではメイン画面側だけを確かめる
@MainActor
struct MainFeatureTests {
    @Test func init_最初の講義を表示する() {
        #expect(MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")])).course.selectedCourseID == "c1")
        #expect(MainFeature.State(bootstrap: .mock(courses: [])).course.selectedCourseID == nil)
    }

    @Test func course_メニューボタンでサイドバーを開く() async {
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        }

        await store.send(.course(.menuButtonTapped))
        await store.receive(\.course.delegate.sidebarRequested) { $0.isSidebarOpen = true }
    }

    @Test func course_利用状況の取り直しをサイドバーへ中継する() async {
        let updated = UsageSummary(costUsd: 0.5, costLimitUsd: 1, courses: 2, courseLimit: 10, periodStart: 0)
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.usage = { updated }
        }

        await store.send(.course(.delegate(.usageRefreshRequested)))
        await store.receive(\.sidebar.usageRefreshRequested)
        await store.receive(\.sidebar.usageRefreshSucceeded) { $0.sidebar.usage = updated }
    }

    @Test func course_更新された講義で行を置き換えても再取得しない() async {
        let updated = CourseSummary.mock("c1", completedSteps: 3)
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))
        initial.course.lectures[id: "c1"]?.detail = CourseDetail(summary: .mock("c1"), currentStepId: nil, steps: [], messages: [])
        let store = TestStore(initialState: initial) {
            MainFeature()
        }

        await store.send(.course(.delegate(.courseUpdated(updated))))
        await store.receive(\.sidebar.courseUpdated) { $0.sidebar.courses = [updated] }
        await store.receive(\.course.coursesChanged) { $0.course.lectures[id: "c1"]?.summary = updated }
    }

    @Test func course_選択していない講義の401でもセッション切れにする() async {
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.course.lectures.append(.init(summary: .mock("c2")))
        let store = TestStore(initialState: initial) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.course = { _ in throw APIClientError.http(status: 401, body: nil) }
        }

        await store.send(.course(.lectures(.element(id: "c2", action: .fetchRequested)))) {
            $0.course.lectures[id: "c2"]?.activity = .fetching
        }
        await store.receive(\.course.lectures[id: "c2"].fetchFailed) {
            $0.course.lectures[id: "c2"]?.activity = .idle
        }
        await store.receive(\.course.lectures[id: "c2"].delegate.sessionExpired)
        await store.receive(\.course.delegate.sessionExpired)
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func sidebar_行を押すと講義を表示してサイドバーを閉じる() async {
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.isSidebarOpen = true
        let store = TestStore(initialState: initial) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.course = { _ in
                CourseDetail(summary: .mock("c2"), currentStepId: nil, steps: [], messages: [])
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sidebar(.courseRowTapped("c2")))
        await store.receive(\.sidebar.delegate.courseSelected) { $0.isSidebarOpen = false }
        await store.receive(\.course.coursesChanged) { $0.course.selectedCourseID = "c2" }
    }

    @Test func peekingMainTapped_選択を変えずにサイドバーを閉じる() async {
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1"), .mock("c2")]))
        initial.isSidebarOpen = true
        let store = TestStore(initialState: initial) {
            MainFeature()
        }

        await store.send(.peekingMainTapped) { $0.isSidebarOpen = false }
    }

    @Test func sidebarSwipedOpen_サイドバーを開く() async {
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        }

        await store.send(.sidebarSwipedOpen) { $0.isSidebarOpen = true }
    }

    @Test func sidebarSwipedClosed_サイドバーを閉じる() async {
        var initial = MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))
        initial.isSidebarOpen = true
        let store = TestStore(initialState: initial) {
            MainFeature()
        }

        await store.send(.sidebarSwipedClosed) { $0.isSidebarOpen = false }
    }

    @Test func sidebar_取り直しの選択に講義が追従する() async {
        let updated = CourseSummary.mock("c1", completedSteps: 3)
        let response = BootstrapResponse.mock(courses: [updated])
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { response }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sidebar(.refreshPulled))
        await store.receive(\.course.coursesChanged) {
            $0.course.lectures[id: "c1"]?.summary = updated
        }
    }

    @Test func sidebar_講義が無くなると空状態にする() async {
        let store = TestStore(initialState: MainFeature.State(bootstrap: .mock(courses: [.mock("c1")]))) {
            MainFeature()
        } withDependencies: {
            $0.apiClient.bootstrap = { .mock(courses: []) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sidebar(.refreshPulled))
        await store.receive(\.course.coursesChanged) {
            $0.course.selectedCourseID = nil
            $0.course.lectures = []
        }
    }
}

extension BootstrapResponse {
    static func mock(courses: [CourseSummary]) -> Self {
        BootstrapResponse(
            user: ApiUser(id: "u1", email: "guest-01@example.com", displayName: "ゲスト01"),
            courses: courses,
            selected: nil,
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
