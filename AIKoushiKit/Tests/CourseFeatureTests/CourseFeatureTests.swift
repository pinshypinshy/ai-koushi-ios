//
//  CourseFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/29.
//

import APIClient
import ComposableArchitecture
@testable import CourseFeature
import Foundation
import Models
import Testing

@MainActor
struct CourseFeatureTests {
    // MARK: - init

    @Test func init_先頭の講義を選択してselectedを持たせる() {
        let detail = CourseDetail.mock("c1")
        let state = CourseFeature.State(courses: [.mock("c1"), .mock("c2")], selected: detail)

        #expect(state.selectedCourseID == "c1")
        #expect(state.items.map(\.id) == ["c1"])
        #expect(state.selectedItem?.lecture.detail == detail)
    }

    @Test func init_講義が無ければ何も選択しない() {
        let state = CourseFeature.State(courses: [], selected: nil)

        #expect(state.selectedCourseID == nil)
        #expect(state.items.isEmpty)
    }

    // MARK: - task

    @Test func task_取得済みなら講義本文を自動で始める() async {
        let store = makeStore(.init(courses: [.mock("c1")], selected: .mock("c1")), withDependencies: {
            $0.apiClient.streamLecture = { _ in .lines(.done(.assistant("a1"))) }
        })

        await store.send(.task)
        await store.receive(\.items[id: "c1"].lecture.startLectureIfNeeded) {
            $0.items[id: "c1"]?.lecture.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.items[id: "c1"].lecture.streamLineReceived) {
            $0.items[id: "c1"]?.lecture.detail = .mock("c1", messages: [.assistant("a1")])
            $0.items[id: "c1"]?.lecture.activity = .idle
        }
        await store.receive(\.items[id: "c1"].lecture.delegate.usageRefreshRequested)
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func task_未取得なら取得する() async {
        let detail = CourseDetail.mock("c1", messages: [.assistant("a1")])
        let store = makeStore(.init(courses: [.mock("c1")], selected: nil), withDependencies: {
            $0.apiClient.course = { _ in detail }
        })

        await store.send(.task)
        await receiveFetch(store, "c1", detail)
    }

    @Test func task_講義が無ければ何もしない() async {
        await makeStore(.init(courses: [], selected: nil)).send(.task)
    }

    // MARK: - menuButtonTapped

    @Test func menuButtonTapped_親にサイドバーを開くよう頼む() async {
        let store = makeStore(.init(courses: [], selected: nil))

        await store.send(.menuButtonTapped)
        await store.receive(\.delegate.sidebarRequested)
    }

    // MARK: - openWebButtonTapped

    @Test func openWebButtonTapped_本番のURLを開く() async {
        let openedURL = LockIsolated<URL?>(nil)
        let store = makeStore(.init(courses: [], selected: nil), withDependencies: {
            $0.openURL = OpenURLEffect { url in
                openedURL.setValue(url)
                return true
            }
        })

        await store.send(.openWebButtonTapped)
        #expect(openedURL.value == URL(string: "https://ai-koushi.yuki-hiraishi.com"))
    }

    // MARK: - coursesChanged

    @Test func coursesChanged_別の講義を選ぶと状態を作って取得する() async {
        let detail = CourseDetail.mock("c2", messages: [.assistant("a1")])
        let store = makeStore(.init(courses: [.mock("c1"), .mock("c2")], selected: .mock("c1")), withDependencies: {
            $0.apiClient.course = { _ in detail }
        })

        await store.send(.coursesChanged(courses: [.mock("c1"), .mock("c2")], selectedCourseID: "c2")) {
            $0.selectedCourseID = "c2"
            $0.items.append(.init(summary: .mock("c2")))
        }
        await receiveFetch(store, "c2", detail)
    }

    @Test func coursesChanged_選択が同じなら取得しない() async {
        let updated = CourseSummary.mock("c1", completedSteps: 1)
        let store = makeStore(.init(courses: [.mock("c1")], selected: .mock("c1")))

        await store.send(.coursesChanged(courses: [updated], selectedCourseID: "c1")) {
            $0.items[id: "c1"]?.lecture.summary = updated
        }
    }

    @Test func coursesChanged_選択が同じでも状態が変われば取得する() async {
        let ready = CourseSummary.mock("c1", status: .ready)
        let detail = CourseDetail.mock("c1", messages: [.assistant("a1")])
        let store = makeStore(.init(courses: [.mock("c1", status: .generating)], selected: .mock("c1", status: .generating)), withDependencies: {
            $0.apiClient.course = { _ in detail }
        })

        await store.send(.coursesChanged(courses: [ready], selectedCourseID: "c1")) {
            $0.items[id: "c1"]?.lecture.summary = ready
        }
        await receiveFetch(store, "c1", detail)
    }

    @Test func coursesChanged_受信中の講義を選び直しても取得しない() async {
        var state = CourseFeature.State(courses: [.mock("c1"), .mock("c2")], selected: .mock("c1"))
        state.items[id: "c1"]?.lecture.activity = .streaming(text: "途中", replacingMessageID: nil)
        state.items.append(.init(summary: .mock("c2")))
        state.selectedCourseID = "c2"
        let store = makeStore(state)

        await store.send(.coursesChanged(courses: [.mock("c1"), .mock("c2")], selectedCourseID: "c1")) {
            $0.selectedCourseID = "c1"
        }
        await store.receive(\.items[id: "c1"].lecture.fetchRequested)
    }

    @Test func coursesChanged_消えた講義の状態を捨てて受信をやめる() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: LectureStreamLine.self, throwing: (any Error).self)
        defer { continuation.finish() }
        let detail = CourseDetail.mock("c2", messages: [.assistant("a1")])
        let store = makeStore(.init(courses: [.mock("c1"), .mock("c2")], selected: .mock("c1")), withDependencies: {
            $0.apiClient.streamLecture = { _ in stream }
            $0.apiClient.course = { _ in detail }
        })

        await store.send(.task)
        await store.receive(\.items[id: "c1"].lecture.startLectureIfNeeded) {
            $0.items[id: "c1"]?.lecture.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.send(.coursesChanged(courses: [.mock("c2")], selectedCourseID: "c2")) {
            $0.selectedCourseID = "c2"
            $0.items = [.init(summary: .mock("c2"))]
        }
        await receiveFetch(store, "c2", detail)
        // やめられていなければ、Effect が終わらないか、届いた Action が未確認のまま残って失敗する
        continuation.yield(.delta("遅れた文字"))
        await store.finish()
    }

    @Test func coursesChanged_0件なら選択を外す() async {
        let store = makeStore(.init(courses: [.mock("c1")], selected: .mock("c1")))

        await store.send(.coursesChanged(courses: [], selectedCourseID: nil)) {
            $0.selectedCourseID = nil
            $0.items = []
        }
    }

    // MARK: - items

    @Test func items_受信中に切り替えても文字はその講義にだけ届く() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: LectureStreamLine.self, throwing: (any Error).self)
        defer { continuation.finish() }
        let c2Detail = CourseDetail.mock("c2", messages: [.assistant("c2-a1")])
        let courses: [CourseSummary] = [.mock("c1"), .mock("c2")]
        let store = makeStore(.init(courses: courses, selected: .mock("c1")), withDependencies: {
            $0.apiClient.streamLecture = { _ in stream }
            $0.apiClient.course = { _ in c2Detail }
        })

        await store.send(.task)
        await store.receive(\.items[id: "c1"].lecture.startLectureIfNeeded) {
            $0.items[id: "c1"]?.lecture.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.send(.coursesChanged(courses: courses, selectedCourseID: "c2")) {
            $0.selectedCourseID = "c2"
            $0.items.append(.init(summary: .mock("c2")))
        }
        await receiveFetch(store, "c2", c2Detail)

        continuation.yield(.delta("続き"))
        await store.receive(\.items[id: "c1"].lecture.streamLineReceived) {
            $0.items[id: "c1"]?.lecture.activity = .streaming(text: "続き", replacingMessageID: nil)
        }

        await store.send(.coursesChanged(courses: courses, selectedCourseID: "c1")) {
            $0.selectedCourseID = "c1"
        }
        await store.receive(\.items[id: "c1"].lecture.fetchRequested)

        continuation.yield(.done(.assistant("c1-a1")))
        await store.receive(\.items[id: "c1"].lecture.streamLineReceived) {
            $0.items[id: "c1"]?.lecture.detail = .mock("c1", messages: [.assistant("c1-a1")])
            $0.items[id: "c1"]?.lecture.activity = .idle
        }
        await store.receive(\.items[id: "c1"].lecture.delegate.usageRefreshRequested)
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func items_別の講義を選んでいる間に完了しても次の本文が始まる() async {
        let (response, finishResponse) = AsyncStream.makeStream(of: Void.self)
        let completed = CourseDetail.mock("c1", currentStepId: "s2", messages: [.assistant("a1")])
        let c2Detail = CourseDetail.mock("c2", messages: [.assistant("c2-a1")])
        let courses: [CourseSummary] = [.mock("c1"), .mock("c2")]
        let store = makeStore(.init(courses: courses, selected: .mock("c1", messages: [.assistant("a1")])), withDependencies: {
            $0.apiClient.completeStep = { _, _ in
                for await _ in response { break }
                return completed
            }
            $0.apiClient.streamLecture = { _ in .lines(.done(.assistant("a2", stepId: "s2"))) }
            $0.apiClient.course = { _ in c2Detail }
        })

        await store.send(.items(.element(id: "c1", action: .lecture(.completeStepButtonTapped)))) {
            $0.items[id: "c1"]?.lecture.activity = .completingStep
        }
        await store.send(.coursesChanged(courses: courses, selectedCourseID: "c2")) {
            $0.selectedCourseID = "c2"
            $0.items.append(.init(summary: .mock("c2")))
        }
        await receiveFetch(store, "c2", c2Detail)

        finishResponse.yield()
        await store.receive(\.items[id: "c1"].lecture.stepCompletionSucceeded) {
            $0.items[id: "c1"]?.lecture.detail = completed
            $0.items[id: "c1"]?.lecture.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.items[id: "c1"].lecture.delegate.courseUpdated)
        await store.receive(\.items[id: "c1"].lecture.delegate.usageRefreshRequested)
        await store.receive(\.delegate.courseUpdated)
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.items[id: "c1"].lecture.streamLineReceived) {
            $0.items[id: "c1"]?.lecture.detail = .mock("c1", currentStepId: "s2", messages: [.assistant("a1"), .assistant("a2", stepId: "s2")])
            $0.items[id: "c1"]?.lecture.activity = .idle
        }
        await store.receive(\.items[id: "c1"].lecture.delegate.usageRefreshRequested)
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func items_通知を親へ中継する() async {
        let updated = CourseSummary.mock("c1", completedSteps: 1)
        let store = makeStore(.init(courses: [.mock("c1")], selected: .mock("c1")))

        await store.send(.items(.element(id: "c1", action: .lecture(.delegate(.sessionExpired)))))
        await store.receive(\.delegate.sessionExpired)
        await store.send(.items(.element(id: "c1", action: .lecture(.delegate(.usageRefreshRequested)))))
        await store.receive(\.delegate.usageRefreshRequested)
        await store.send(.items(.element(id: "c1", action: .lecture(.delegate(.courseUpdated(updated))))))
        await store.receive(\.delegate.courseUpdated, updated)
    }

    // MARK: - 補助

    private func makeStore(
        _ state: CourseFeature.State,
        withDependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<CourseFeature> {
        TestStore(initialState: state) {
            CourseFeature()
        } withDependencies: {
            withDependencies(&$0)
        }
    }

    /// 取得が始まってから、発言のある講義の取得が成功し、親へ知らせるまで
    private func receiveFetch(_ store: TestStoreOf<CourseFeature>, _ id: String, _ detail: CourseDetail) async {
        await store.receive(\.items[id: id].lecture.fetchRequested) {
            $0.items[id: id]?.lecture.activity = .fetching
        }
        await store.receive(\.items[id: id].lecture.fetchSucceeded) {
            $0.items[id: id]?.lecture.detail = detail
            $0.items[id: id]?.lecture.activity = .idle
        }
        await store.receive(\.items[id: id].lecture.delegate.courseUpdated)
        await store.receive(\.delegate.courseUpdated)
    }
}

extension AsyncThrowingStream<LectureStreamLine, any Error> {
    fileprivate static func lines(_ lines: LectureStreamLine...) -> Self {
        AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }
}

extension CourseSummary {
    fileprivate static func mock(_ id: String, status: CourseStatus = .ready, completedSteps: Int = 0) -> CourseSummary {
        CourseSummary(
            id: id, title: "講義 \(id)", status: status, quizStatus: .pending, phase: nil, errorMessage: nil,
            totalSteps: 2, completedSteps: completedSteps, updatedAt: 0
        )
    }
}

extension CourseDetail {
    fileprivate static func mock(
        _ id: String,
        status: CourseStatus = .ready,
        currentStepId: String? = "s1",
        messages: [ApiMessage] = []
    ) -> CourseDetail {
        CourseDetail(
            summary: .mock(id, status: status),
            currentStepId: currentStepId,
            steps: [
                ApiStep(id: "s1", orderIndex: 1, title: "はじめに", status: .inProgress),
                ApiStep(id: "s2", orderIndex: 2, title: "まとめ", status: .notStarted),
            ],
            messages: messages
        )
    }
}

extension ApiMessage {
    fileprivate static func assistant(_ id: String, stepId: String = "s1") -> ApiMessage {
        ApiMessage(id: id, stepId: stepId, role: .assistant, content: "本文", interrupted: false)
    }
}
