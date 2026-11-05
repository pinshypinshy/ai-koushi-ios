//
//  LectureFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/05.
//

import APIClient
import ComposableArchitecture
import ConversationWebView
@testable import CourseFeature
import Foundation
import Models
import Testing

private let busyActivities: [LectureFeature.Activity] = [
    .streaming(text: "", replacingMessageID: nil),
    .completingStep,
    .fetching,
    .reloading(partialText: nil),
]

@MainActor
struct LectureFeatureTests {
    // MARK: - fetchRequested

    @Test(arguments: busyActivities)
    func fetchRequested_処理の最中は何もしない(activity: LectureFeature.Activity) async {
        await makeStore(busyState(activity)).send(.fetchRequested)
    }

    // MARK: - summaryChanged

    @Test func summaryChanged_要約を更新する() async {
        let changed = CourseSummary.mock(status: .failed)

        await makeStore(.init(summary: .mock())).send(.summaryChanged(changed)) { $0.summary = changed }
    }

    // MARK: - startLectureIfNeeded

    @Test func startLectureIfNeeded_発言の無いステップで1回だけ呼ぶ() async {
        let calls = LockIsolated(0)
        let done = ApiMessage.assistant("a1")
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in
                calls.withValue { $0 += 1 }
                return .lines(.done(done))
            }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [done])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)

        await store.send(.startLectureIfNeeded)
        #expect(calls.value == 1)
    }

    @Test func shouldStartLecture_条件を満たさなければfalseになる() {
        var streaming = LectureFeature.State(summary: .mock(), detail: .mock())
        streaming.activity = .streaming(text: "", replacingMessageID: nil)
        #expect(!streaming.shouldStartLecture)

        var failed = LectureFeature.State(summary: .mock(), detail: .mock())
        failed.streamErrorMessage = "失敗"
        #expect(!failed.shouldStartLecture)

        #expect(!LectureFeature.State(summary: .mock(), detail: .mock(currentStepId: nil)).shouldStartLecture)
        #expect(!LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")])).shouldStartLecture)
        #expect(!LectureFeature.State(summary: .mock(), detail: .mock(status: .generating)).shouldStartLecture)
        #expect(!LectureFeature.State(summary: .mock()).shouldStartLecture)
    }

    // MARK: - draftChanged

    @Test func draftChanged_入力欄の文字を更新する() async {
        await makeStore(.init(summary: .mock())).send(.draftChanged("下書き")) { $0.draft = "下書き" }
    }

    // MARK: - sendButtonTapped

    @Test func sendButtonTapped_質問をすぐ表示して入力欄を空にする() async {
        let sent = LockIsolated<String?>(nil)
        let answer = ApiMessage.assistant("a2", content: "回答")
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.draft = "  質問\n"
        let store = makeStore(state, withDependencies: {
            $0.apiClient.sendMessage = { _, text in
                sent.setValue(text)
                return .lines(.done(answer))
            }
        })

        await store.send(.sendButtonTapped) {
            $0.detail = .mock(messages: [.assistant("a1"), .user(Self.firstLocalID, content: "質問")])
            $0.draft = ""
            $0.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [.assistant("a1"), .user(Self.firstLocalID, content: "質問"), answer])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
        #expect(sent.value == "質問")
    }

    @Test func sendButtonTapped_全ステップ完了後は最後のステップに紐づける() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(currentStepId: nil, messages: [.assistant("a1", stepId: "s2")]))
        state.draft = "質問"
        let store = makeStore(state, withDependencies: {
            $0.apiClient.sendMessage = { _, _ in .lines(.done(.assistant("a2", stepId: "s2"))) }
        })

        await store.send(.sendButtonTapped) {
            $0.detail = .mock(currentStepId: nil, messages: [.assistant("a1", stepId: "s2"), .user(Self.firstLocalID, stepId: "s2", content: "質問")])
            $0.draft = ""
            $0.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(currentStepId: nil, messages: [
                .assistant("a1", stepId: "s2"),
                .user(Self.firstLocalID, stepId: "s2", content: "質問"),
                .assistant("a2", stepId: "s2"),
            ])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func sendButtonTapped_受信のエラーを消す() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.streamErrorMessage = "失敗"
        state.draft = "質問"
        let store = makeStore(state, withDependencies: {
            $0.apiClient.sendMessage = { _, _ in .lines(.done(.assistant("a2"))) }
        })

        await store.send(.sendButtonTapped) {
            $0.detail = .mock(messages: [.assistant("a1"), .user(Self.firstLocalID, content: "質問")])
            $0.draft = ""
            $0.streamErrorMessage = nil
            $0.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [.assistant("a1"), .user(Self.firstLocalID, content: "質問"), .assistant("a2")])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func sendButtonTapped_空白だけなら何もしない() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.draft = " \n "
        await makeStore(state).send(.sendButtonTapped)
    }

    @Test(arguments: busyActivities)
    func sendButtonTapped_処理の最中は何もしない(activity: LectureFeature.Activity) async {
        await makeStore(busyState(activity)).send(.sendButtonTapped)
    }

    // MARK: - regenerateButtonTapped

    @Test func regenerateButtonTapped_途切れた発言を隠して受信を始める() async {
        let interrupted = ApiMessage.assistant("local-1", content: "途中", interrupted: true)
        let regenerated = ApiMessage.assistant("server", content: "全文")
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.user("u1"), interrupted])), withDependencies: {
            $0.apiClient.regenerate = { _ in .lines(.done(regenerated)) }
        })

        await store.send(.regenerateButtonTapped) { $0.activity = .streaming(text: "", replacingMessageID: "local-1") }
        #expect(store.state.conversationContent?.items.contains { $0 == .assistant(id: "local-1", markdown: "途中") } == false)
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [.user("u1"), regenerated])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test(arguments: busyActivities)
    func regenerateButtonTapped_処理の最中は何もしない(activity: LectureFeature.Activity) async {
        await makeStore(busyState(activity)).send(.regenerateButtonTapped)
    }

    @Test func canRegenerate_要件の条件どおりに判定する() {
        func state(currentStepId: String? = "s1", messages: [ApiMessage] = [], error: String? = nil) -> LectureFeature.State {
            var state = LectureFeature.State(summary: .mock(), detail: .mock(currentStepId: currentStepId, messages: messages))
            state.streamErrorMessage = error
            return state
        }
        // 回答の無い質問・途切れた発言
        #expect(state(messages: [.user("u1")]).canRegenerate)
        #expect(state(messages: [.assistant("a1", interrupted: true)]).canRegenerate)
        // 完結している発言
        #expect(!state(messages: [.assistant("a1")]).canRegenerate)
        // 発言の無いステップでの失敗
        #expect(state(error: "失敗").canRegenerate)
        #expect(!state().canRegenerate)
        // 全ステップ完了後は質問への回答だけ
        #expect(state(currentStepId: nil, messages: [.user("u1", stepId: "s2")]).canRegenerate)
        #expect(state(currentStepId: nil, messages: [.user("u1", stepId: "s2"), .assistant("a1", stepId: "s2", interrupted: true)]).canRegenerate)
        #expect(!state(currentStepId: nil, messages: [.assistant("a1", stepId: "s2", interrupted: true)]).canRegenerate)
        #expect(!state(currentStepId: nil, error: "失敗").canRegenerate)
    }

    // MARK: - completeStepButtonTapped

    @Test func completeStepButtonTapped_完了のエラーを消す() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.stepCompletionErrorMessage = "失敗"
        let store = makeStore(state, withDependencies: {
            $0.apiClient.completeStep = { _, _ in throw APIClientError.network }
        })

        await store.send(.completeStepButtonTapped) {
            $0.stepCompletionErrorMessage = nil
            $0.activity = .completingStep
        }
        await store.receive(\.stepCompletionFailed) {
            $0.stepCompletionErrorMessage = LectureFeature.networkErrorMessage
            $0.activity = .idle
        }
    }

    @Test func completeStepButtonTapped_発言が無ければ何もしない() async {
        await makeStore(.init(summary: .mock(), detail: .mock())).send(.completeStepButtonTapped)
    }

    @Test(arguments: busyActivities)
    func completeStepButtonTapped_処理の最中は何もしない(activity: LectureFeature.Activity) async {
        await makeStore(busyState(activity)).send(.completeStepButtonTapped)
    }

    // MARK: - retryFetchButtonTapped

    @Test func retryFetchButtonTapped_エラーを消して取得し直す() async {
        var state = LectureFeature.State(summary: .mock())
        state.fetchError = .network
        let detail = CourseDetail.mock(messages: [.assistant("a1")])
        let store = makeStore(state, withDependencies: { $0.apiClient.course = { _ in detail } })

        await store.send(.retryFetchButtonTapped) {
            $0.fetchError = nil
            $0.activity = .fetching
        }
        await store.receive(\.fetchSucceeded) {
            $0.detail = detail
            $0.activity = .idle
        }
    }

    // MARK: - progressPanelTapped

    @Test func progressPanelTapped_開閉を切り替える() async {
        let store = makeStore(.init(summary: .mock()))

        await store.send(.progressPanelTapped) { $0.isProgressExpanded = true }
        await store.send(.progressPanelTapped) { $0.isProgressExpanded = false }
    }

    // MARK: - linkTapped

    @Test func linkTapped_ブラウザで開く() async {
        let opened = LockIsolated<URL?>(nil)
        let url = URL(string: "https://example.com")
        let store = makeStore(.init(summary: .mock()), withDependencies: {
            $0.openURL = OpenURLEffect { url in
                opened.setValue(url)
                return true
            }
        })

        if let url {
            await store.send(.linkTapped(url))
        }
        #expect(opened.value == url)
    }

    // MARK: - fetchSucceeded

    @Test func fetchSucceeded_発言があれば講義本文を始めない() async {
        let detail = CourseDetail.mock(messages: [.assistant("a1")])
        let store = makeStore(.init(summary: .mock()), withDependencies: { $0.apiClient.course = { _ in detail } })

        await store.send(.fetchRequested) { $0.activity = .fetching }
        await store.receive(\.fetchSucceeded) {
            $0.detail = detail
            $0.activity = .idle
        }
    }

    @Test func fetchSucceeded_発言が無ければ講義本文を始める() async {
        let detail = CourseDetail.mock()
        let store = makeStore(.init(summary: .mock()), withDependencies: {
            $0.apiClient.course = { _ in detail }
            $0.apiClient.streamLecture = { _ in .lines(.done(.assistant("a1"))) }
        })

        await store.send(.fetchRequested) { $0.activity = .fetching }
        await store.receive(\.fetchSucceeded) {
            $0.detail = detail
            $0.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [.assistant("a1")])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    // MARK: - fetchFailed

    @Test(arguments: [
        (APIClientError.http(status: 404, body: nil), LectureFeature.FetchError.notFound),
        (.network, .network),
        (.http(status: 500, body: nil), .other),
        (.decoding, .other),
    ])
    func fetchFailed_結果ごとのエラーを表示する(error: APIClientError, expected: LectureFeature.FetchError) async {
        let store = makeStore(.init(summary: .mock()), withDependencies: { $0.apiClient.course = { _ in throw error } })

        await store.send(.fetchRequested) { $0.activity = .fetching }
        await store.receive(\.fetchFailed) {
            $0.activity = .idle
            $0.fetchError = expected
        }
    }

    @Test func fetchFailed_会話を残す() async {
        let detail = CourseDetail.mock(messages: [.assistant("a1")])
        let store = makeStore(.init(summary: .mock(), detail: detail), withDependencies: {
            $0.apiClient.course = { _ in throw APIClientError.network }
        })

        await store.send(.fetchRequested) { $0.activity = .fetching }
        await store.receive(\.fetchFailed) {
            $0.activity = .idle
            $0.fetchError = .network
        }
        #expect(store.state.detail == detail)
    }

    @Test func fetchFailed_401ならセッション切れにする() async {
        let store = makeStore(.init(summary: .mock()), withDependencies: {
            $0.apiClient.course = { _ in throw APIClientError.http(status: 401, body: nil) }
        })

        await store.send(.fetchRequested) { $0.activity = .fetching }
        await store.receive(\.fetchFailed) { $0.activity = .idle }
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func fetchFailed_取り消しでは何もしない() async {
        var state = LectureFeature.State(summary: .mock())
        state.activity = .fetching

        await makeStore(state).send(.fetchFailed(CancellationError()))
    }

    // MARK: - streamLineReceived

    @Test func streamLineReceived_deltaとdoneで文字を足して発言を確定する() async {
        let done = ApiMessage.assistant("a1", content: "本文")
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in .lines(.delta("本"), .delta("文"), .done(done)) }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) { $0.activity = .streaming(text: "本", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) { $0.activity = .streaming(text: "本文", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [done])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func streamLineReceived_doneで隠した発言を置き換える() async {
        let regenerated = ApiMessage.assistant("server", content: "全文")
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [
            .user("u1"),
            .assistant("local-1", content: "途中", interrupted: true),
        ]))
        state.activity = .streaming(text: "全文", replacingMessageID: "local-1")
        let store = makeStore(state)

        await store.send(.streamLineReceived(.done(regenerated))) {
            $0.detail = .mock(messages: [.user("u1"), regenerated])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func streamLineReceived_doneで回答の無い質問に回答を足す() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.user("u1")])), withDependencies: {
            $0.apiClient.regenerate = { _ in .lines(.done(.assistant("a1"))) }
        })

        await store.send(.regenerateButtonTapped) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(messages: [.user("u1"), .assistant("a1")])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func streamLineReceived_errorの文言を出さず途中の文字を残す() async {
        let reloaded = CourseDetail.mock(messages: [.assistant("server", content: "途中", interrupted: true)])
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in .lines(.delta("途中"), .error(message: "内部エラー")) }
            $0.apiClient.course = { _ in reloaded }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) { $0.activity = .streaming(text: "途中", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) {
            $0.streamErrorMessage = LectureFeature.streamInterruptedMessage
            $0.activity = .reloading(partialText: "途中")
        }
        #expect(store.state.conversationContent?.streaming == "途中")
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.reloadSucceeded) {
            $0.detail = reloaded
            $0.activity = .idle
        }
    }

    @Test func streamLineReceived_errorで途中の文字が隠した発言に代わる() async {
        let interrupted = ApiMessage.assistant("a1", content: "前の途中", interrupted: true)
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [interrupted])), withDependencies: {
            $0.apiClient.regenerate = { _ in .lines(.delta("新しい途中"), .error(message: "内部エラー")) }
            $0.apiClient.course = { _ in throw APIClientError.network }
        })

        await store.send(.regenerateButtonTapped) { $0.activity = .streaming(text: "", replacingMessageID: "a1") }
        await store.receive(\.streamLineReceived) { $0.activity = .streaming(text: "新しい途中", replacingMessageID: "a1") }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock()
            $0.streamErrorMessage = LectureFeature.streamInterruptedMessage
            $0.activity = .reloading(partialText: "新しい途中")
        }
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.reloadFailed) {
            $0.detail = .mock(messages: [.assistant(Self.firstLocalID, content: "新しい途中", interrupted: true)])
            $0.activity = .idle
        }
    }

    @Test(arguments: [
        LectureStreamLine.delta("文字"),
        .done(.assistant("a1")),
        .error(message: "内部エラー"),
    ])
    func streamLineReceived_受信中でなければ無視する(line: LectureStreamLine) async {
        await makeStore(.init(summary: .mock(), detail: .mock())).send(.streamLineReceived(line))
    }

    // MARK: - streamEndedWithoutDone

    @Test func streamEndedWithoutDone_途中で止まったと表示する() async {
        let reloaded = CourseDetail.mock()
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in .lines() }
            $0.apiClient.course = { _ in reloaded }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamEndedWithoutDone) {
            $0.streamErrorMessage = LectureFeature.streamInterruptedMessage
            $0.activity = .reloading(partialText: nil)
        }
        await store.receive(\.delegate.usageRefreshRequested)
        // エラーを表示しているので、同じステップの講義本文を自動で呼び直さない（§4.7）
        await store.receive(\.reloadSucceeded) { $0.activity = .idle }
    }

    // MARK: - streamFailed

    @Test(arguments: [
        (APIClientError.http(status: 403, body: ApiError(error: "limit", message: "上限に達しました")), "上限に達しました"),
        (.network, LectureFeature.networkErrorMessage),
        (.http(status: 403, body: nil), LectureFeature.streamOtherErrorMessage),
        (.http(status: 500, body: nil), LectureFeature.streamOtherErrorMessage),
        (.decoding, LectureFeature.streamOtherErrorMessage),
    ])
    func streamFailed_結果ごとの文言を表示して読み直す(error: APIClientError, expected: String) async {
        let reloaded = CourseDetail.mock(messages: [.assistant("server")])
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in .failing(error) }
            $0.apiClient.course = { _ in reloaded }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamFailed) {
            $0.streamErrorMessage = expected
            $0.activity = .reloading(partialText: nil)
        }
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.reloadSucceeded) {
            $0.detail = reloaded
            $0.activity = .idle
        }
    }

    @Test func streamFailed_401ならセッション切れにする() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in .failing(.http(status: 401, body: nil)) }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamFailed)
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func streamFailed_文字が無ければ隠した発言を表示に戻す() async {
        let interrupted = ApiMessage.assistant("a1", content: "途中", interrupted: true)
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [interrupted])), withDependencies: {
            $0.apiClient.regenerate = { _ in .failing(.network) }
            $0.apiClient.course = { _ in throw APIClientError.network }
        })

        await store.send(.regenerateButtonTapped) { $0.activity = .streaming(text: "", replacingMessageID: "a1") }
        await store.receive(\.streamFailed) {
            $0.streamErrorMessage = LectureFeature.networkErrorMessage
            $0.activity = .reloading(partialText: nil)
        }
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.reloadFailed) { $0.activity = .idle }
        #expect(store.state.detail?.messages == [interrupted])
    }

    @Test func streamFailed_取り消しでは何もしない() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock())
        state.activity = .streaming(text: "途中", replacingMessageID: nil)

        await makeStore(state).send(.streamFailed(CancellationError()))
    }

    // MARK: - reloadSucceeded

    @Test func reloadSucceeded_次のステップへ進んでいたら講義本文を始める() async {
        let reloaded = CourseDetail.mock(currentStepId: "s2", messages: [.assistant("a1")])
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.activity = .reloading(partialText: nil)
        let store = makeStore(state, withDependencies: {
            $0.apiClient.streamLecture = { _ in .lines(.done(.assistant("a2", stepId: "s2"))) }
        })

        await store.send(.reloadSucceeded(reloaded)) {
            $0.detail = reloaded
            $0.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(currentStepId: "s2", messages: [.assistant("a1"), .assistant("a2", stepId: "s2")])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
    }

    // MARK: - reloadFailed

    @Test func reloadFailed_途中の文字を途切れた発言として残す() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock()), withDependencies: {
            $0.apiClient.streamLecture = { _ in .lines(.delta("途中"), .error(message: "内部エラー")) }
            $0.apiClient.course = { _ in throw APIClientError.network }
        })

        await store.send(.startLectureIfNeeded) { $0.activity = .streaming(text: "", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) { $0.activity = .streaming(text: "途中", replacingMessageID: nil) }
        await store.receive(\.streamLineReceived) {
            $0.streamErrorMessage = LectureFeature.streamInterruptedMessage
            $0.activity = .reloading(partialText: "途中")
        }
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.reloadFailed) {
            $0.detail = .mock(messages: [.assistant(Self.firstLocalID, content: "途中", interrupted: true)])
            $0.activity = .idle
        }
    }

    @Test func reloadFailed_401ならセッション切れにする() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock())
        state.activity = .reloading(partialText: nil)
        let store = makeStore(state)

        await store.send(.reloadFailed(APIClientError.http(status: 401, body: nil)))
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func reloadFailed_取り消しでは何もしない() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock())
        state.activity = .reloading(partialText: "途中")

        await makeStore(state).send(.reloadFailed(CancellationError()))
    }

    // MARK: - stepCompletionSucceeded

    @Test func stepCompletionSucceeded_講義を置き換えて次の講義本文を始める() async {
        let completed = CourseDetail.mock(currentStepId: "s2", messages: [.assistant("a1")])
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.streamErrorMessage = "失敗"
        let requested = LockIsolated<[String]>([])
        let store = makeStore(state, withDependencies: {
            $0.apiClient.completeStep = { _, stepID in
                requested.withValue { $0.append(stepID) }
                return completed
            }
            $0.apiClient.streamLecture = { _ in .lines(.done(.assistant("a2", stepId: "s2"))) }
        })

        await store.send(.completeStepButtonTapped) { $0.activity = .completingStep }
        await store.receive(\.stepCompletionSucceeded) {
            $0.detail = completed
            $0.streamErrorMessage = nil
            $0.activity = .streaming(text: "", replacingMessageID: nil)
        }
        await store.receive(\.delegate.courseUpdated)
        await store.receive(\.delegate.usageRefreshRequested)
        await store.receive(\.streamLineReceived) {
            $0.detail = .mock(currentStepId: "s2", messages: [.assistant("a1"), .assistant("a2", stepId: "s2")])
            $0.activity = .idle
        }
        await store.receive(\.delegate.usageRefreshRequested)
        #expect(requested.value == ["s1"])
    }

    @Test func stepCompletionSucceeded_返った講義の要約を親に渡す() async {
        let completed = CourseDetail.mock(currentStepId: nil, completedSteps: 2, messages: [.assistant("a1")])
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.assistant("a1")])), withDependencies: {
            $0.apiClient.completeStep = { _, _ in completed }
        })

        await store.send(.completeStepButtonTapped) { $0.activity = .completingStep }
        await store.receive(\.stepCompletionSucceeded) {
            $0.summary = completed.summary
            $0.detail = completed
            $0.activity = .idle
        }
        await store.receive(\.delegate.courseUpdated, completed.summary)
        await store.receive(\.delegate.usageRefreshRequested)
    }

    @Test func stepCompletionSucceeded_最後のステップなら講義本文を始めない() async {
        let calls = LockIsolated(0)
        let completed = CourseDetail.mock(currentStepId: nil, messages: [.assistant("a1")])
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.assistant("a1")])), withDependencies: {
            $0.apiClient.completeStep = { _, _ in completed }
            $0.apiClient.streamLecture = { _ in
                calls.withValue { $0 += 1 }
                return .lines()
            }
        })

        await store.send(.completeStepButtonTapped) { $0.activity = .completingStep }
        await store.receive(\.stepCompletionSucceeded) {
            $0.detail = completed
            $0.activity = .idle
        }
        await store.receive(\.delegate.courseUpdated)
        await store.receive(\.delegate.usageRefreshRequested)
        #expect(calls.value == 0)
    }

    // MARK: - stepCompletionFailed

    @Test func stepCompletionFailed_通信エラーなら文言だけ表示する() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.assistant("a1")])), withDependencies: {
            $0.apiClient.completeStep = { _, _ in throw APIClientError.network }
        })

        await store.send(.completeStepButtonTapped) { $0.activity = .completingStep }
        await store.receive(\.stepCompletionFailed) {
            $0.stepCompletionErrorMessage = LectureFeature.networkErrorMessage
            $0.activity = .idle
        }
    }

    @Test func stepCompletionFailed_409なら文言を表示して読み直す() async {
        let reloaded = CourseDetail.mock(currentStepId: nil, messages: [.assistant("a1")])
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.assistant("a1")])), withDependencies: {
            $0.apiClient.completeStep = { _, _ in throw APIClientError.http(status: 409, body: nil) }
            $0.apiClient.course = { _ in reloaded }
        })

        await store.send(.completeStepButtonTapped) { $0.activity = .completingStep }
        await store.receive(\.stepCompletionFailed) {
            $0.stepCompletionErrorMessage = LectureFeature.stepCompletionOtherErrorMessage
            $0.activity = .reloading(partialText: nil)
        }
        await store.receive(\.reloadSucceeded) {
            $0.detail = reloaded
            $0.activity = .idle
        }
    }

    @Test func stepCompletionFailed_401ならセッション切れにする() async {
        let store = makeStore(.init(summary: .mock(), detail: .mock(messages: [.assistant("a1")])), withDependencies: {
            $0.apiClient.completeStep = { _, _ in throw APIClientError.http(status: 401, body: nil) }
        })

        await store.send(.completeStepButtonTapped) { $0.activity = .completingStep }
        await store.receive(\.stepCompletionFailed)
        await store.receive(\.delegate.sessionExpired)
    }

    @Test func stepCompletionFailed_取り消しでは何もしない() async {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1")]))
        state.activity = .completingStep

        await makeStore(state).send(.stepCompletionFailed(CancellationError()))
    }

    // MARK: - conversationContent

    @Test func conversationContent_ステップごとの最初の発言の前に区切りを入れる() {
        let state = LectureFeature.State(summary: .mock(), detail: .mock(
            currentStepId: "s2",
            messages: [.assistant("a1"), .user("u1"), .assistant("a2", stepId: "s2")]
        ))
        #expect(state.conversationContent == ConversationContent(
            id: "c1",
            items: [
                .divider(id: "divider-s1", label: "ステップ 1・はじめに"),
                .assistant(id: "a1", markdown: "本文"),
                .user(id: "u1", text: "本文"),
                .divider(id: "divider-s2", label: "ステップ 2・まとめ"),
                .assistant(id: "a2", markdown: "本文"),
            ],
            streaming: nil
        ))
    }

    @Test func conversationContent_新しいステップの受信中の発言の前に区切りを入れる() {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(currentStepId: "s2", messages: [.assistant("a1")]))
        state.activity = .streaming(text: "", replacingMessageID: nil)
        #expect(state.conversationContent == ConversationContent(
            id: "c1",
            items: [
                .divider(id: "divider-s1", label: "ステップ 1・はじめに"),
                .assistant(id: "a1", markdown: "本文"),
                .divider(id: "divider-s2", label: "ステップ 2・まとめ"),
            ],
            streaming: ""
        ))
    }

    @Test func conversationContent_途切れた発言の下に注記を出す() {
        let state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.assistant("a1", interrupted: true)]))
        #expect(state.conversationContent?.items.last == .notice(id: "interrupted-a1", text: "応答が途中で途切れました"))
    }

    @Test func conversationContent_再生成できるときだけ回答の無い質問の下に注記を出す() {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.user("u1")]))
        #expect(state.conversationContent?.items.last == .notice(id: "unanswered-u1", text: "応答を取得できませんでした"))

        state.activity = .streaming(text: "", replacingMessageID: nil)
        #expect(state.conversationContent?.items.last == .user(id: "u1", text: "本文"))
    }

    // MARK: - visibleStreamError

    @Test func visibleStreamError_再生成の対象が会話に無いときだけ表示する() {
        var empty = LectureFeature.State(summary: .mock(), detail: .mock())
        empty.streamErrorMessage = "失敗"
        #expect(empty.visibleStreamError == "失敗")

        var unanswered = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.user("u1")]))
        unanswered.streamErrorMessage = "失敗"
        #expect(unanswered.visibleStreamError == nil)
    }

    // MARK: - 補助

    /// `UUIDGenerator.incrementing` が最初に返す値
    private static let firstLocalID = "local-00000000-0000-0000-0000-000000000000"

    /// 待機中でなければ、送信・再生成・ステップ完了のどれも押せる状態
    private func busyState(_ activity: LectureFeature.Activity) -> LectureFeature.State {
        var state = LectureFeature.State(summary: .mock(), detail: .mock(messages: [.user("u1")]))
        state.draft = "質問"
        state.activity = activity
        return state
    }

    private func makeStore(
        _ state: LectureFeature.State,
        withDependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<LectureFeature> {
        TestStore(initialState: state) {
            LectureFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            withDependencies(&$0)
        }
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

    fileprivate static func failing(_ error: APIClientError) -> Self {
        AsyncThrowingStream { $0.finish(throwing: error) }
    }
}

extension CourseSummary {
    fileprivate static func mock(status: CourseStatus = .ready, completedSteps: Int = 0) -> CourseSummary {
        CourseSummary(
            id: "c1",
            title: "講義",
            status: status,
            quizStatus: .pending,
            phase: nil,
            errorMessage: nil,
            totalSteps: 2,
            completedSteps: completedSteps,
            updatedAt: 0
        )
    }
}

extension CourseDetail {
    fileprivate static func mock(
        status: CourseStatus = .ready,
        currentStepId: String? = "s1",
        completedSteps: Int = 0,
        messages: [ApiMessage] = []
    ) -> CourseDetail {
        CourseDetail(
            summary: .mock(status: status, completedSteps: completedSteps),
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
    fileprivate static func assistant(_ id: String, stepId: String = "s1", content: String = "本文", interrupted: Bool = false) -> ApiMessage {
        ApiMessage(id: id, stepId: stepId, role: .assistant, content: content, interrupted: interrupted)
    }

    fileprivate static func user(_ id: String, stepId: String = "s1", content: String = "本文") -> ApiMessage {
        ApiMessage(id: id, stepId: stepId, role: .user, content: content, interrupted: false)
    }
}
