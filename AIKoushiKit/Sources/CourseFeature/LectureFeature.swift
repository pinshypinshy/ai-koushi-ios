//
//  LectureFeature.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/05.
//

import APIClient
import ComposableArchitecture
import ConversationWebView
import Foundation
import Models

/// 講義1つ分の状態と振る舞い。講義ごとに持ち続ける（ADR 0004）
@Reducer
public struct LectureFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let id: CourseSummary.ID
        var summary: CourseSummary
        var detail: CourseDetail?
        var activity: Activity = .idle
        var fetchError: FetchError?
        var streamErrorMessage: String?
        var stepCompletionErrorMessage: String?
        var draft = ""
        var isProgressExpanded = false

        public init(summary: CourseSummary, detail: CourseDetail? = nil) {
            self.id = summary.id
            self.summary = summary
            self.detail = detail
        }
    }

    /// 同時に1つしか走らせない。読み直しや取得の結果で、別の操作の結果を上書きしないため（§4.6・§4.9）
    enum Activity: Equatable {
        case idle
        case fetching
        case streaming(text: String, replacingMessageID: ApiMessage.ID?)
        case reloading(partialText: String?)
        case completingStep
    }

    enum FetchError: Equatable {
        case notFound
        case network
        case other

        var message: String {
            switch self {
            case .notFound: "講義が見つかりませんでした。サイドバーの一覧を下に引っ張って更新してください。"
            case .network: LectureFeature.networkErrorMessage
            case .other: "講義を読み込めませんでした。時間をおいて再度お試しください。"
            }
        }

        var canRetry: Bool {
            self != .notFound
        }
    }

    public enum Action {
        case fetchRequested
        case startLectureIfNeeded

        case draftChanged(String)
        case sendButtonTapped
        case regenerateButtonTapped
        case completeStepButtonTapped
        case retryFetchButtonTapped
        case progressPanelTapped
        case linkTapped(URL)

        case fetchSucceeded(CourseDetail)
        case fetchFailed(any Error)
        case streamLineReceived(LectureStreamLine)
        case streamEndedWithoutDone
        case streamFailed(any Error)
        case reloadSucceeded(CourseDetail)
        case reloadFailed(any Error)
        case stepCompletionSucceeded(CourseDetail)
        case stepCompletionFailed(any Error)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case sessionExpired
            case usageRefreshRequested
            case courseUpdated(CourseSummary)
        }
    }

    static let networkErrorMessage = "通信できませんでした。ネットワーク接続を確認してください。"
    static let streamInterruptedMessage = "応答が途中で止まりました。"
    static let streamOtherErrorMessage = "応答を取得できませんでした。時間をおいて再度お試しください。"
    static let stepCompletionOtherErrorMessage = "ステップを完了できませんでした。時間をおいて再度お試しください。"

    private enum CancelID { case activity }

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.openURL) var openURL
    @Dependency(\.uuid) var uuid

    public init() {}
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchRequested, .retryFetchButtonTapped:
                return fetch(&state)
                
            case .startLectureIfNeeded:
                return startLectureIfNeeded(&state)
                
            case let .draftChanged(text):
                state.draft = text
                return .none

            case .sendButtonTapped:
                return send(&state)

            case .regenerateButtonTapped:
                return regenerate(&state)

            case .completeStepButtonTapped:
                return completeStep(&state)

            case .progressPanelTapped:
                state.isProgressExpanded.toggle()
                return .none

            case let .linkTapped(url):
                return .run { [openURL] _ in
                    await openURL(url)
                }

            case let .fetchSucceeded(detail):
                state.replaceCourse(with: detail)
                return .merge(
                    .send(.delegate(.courseUpdated(detail.summary))),
                    startLectureIfNeeded(&state)
                )

            case let .fetchFailed(error):
                if error is CancellationError { return .none }
                state.activity = .idle
                switch error {
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                case APIClientError.http(status: 404, body: _):
                    state.fetchError = .notFound
                case APIClientError.network:
                    state.fetchError = .network
                default:
                    state.fetchError = .other
                }
                return .none

            case let .streamLineReceived(line):
                return receive(line, into: &state)

            case .streamEndedWithoutDone:
                return failStream(&state, message: Self.streamInterruptedMessage)

            case let .streamFailed(error):
                switch error {
                case is CancellationError:
                    return .none
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                case let APIClientError.http(status: 403, body: body?):
                    return failStream(&state, message: body.message)
                case APIClientError.network:
                    return failStream(&state, message: Self.networkErrorMessage)
                default:
                    return failStream(&state, message: Self.streamOtherErrorMessage)
                }

            case let .reloadSucceeded(detail):
                state.replaceCourse(with: detail)
                return .merge(
                    .send(.delegate(.courseUpdated(detail.summary))),
                    startLectureIfNeeded(&state)
                )

            case let .reloadFailed(error):
                switch error {
                case is CancellationError:
                    return .none
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                default:
                    state.keepPartialTextAsInterruptedMessage(id: "local-\(uuid().uuidString)")
                    state.activity = .idle
                    return .none
                }

            case let .stepCompletionSucceeded(detail):
                state.replaceCourse(with: detail)
                state.streamErrorMessage = nil
                return .merge(
                    .send(.delegate(.courseUpdated(detail.summary))),
                    .send(.delegate(.usageRefreshRequested)),
                    startLectureIfNeeded(&state)
                )

            case let .stepCompletionFailed(error):
                switch error {
                case is CancellationError:
                    return .none
                case APIClientError.http(status: 401, body: _):
                    return .send(.delegate(.sessionExpired))
                case APIClientError.network:
                    state.stepCompletionErrorMessage = Self.networkErrorMessage
                    state.activity = .idle
                    return .send(.delegate(.usageRefreshRequested))
                default:
                    state.stepCompletionErrorMessage = Self.stepCompletionOtherErrorMessage
                    state.activity = .reloading(partialText: nil)
                    return .merge(
                        .send(.delegate(.usageRefreshRequested)),
                        reload(state)
                    )
                }

            case .delegate:
                return .none
            }
        }
    }

    private func fetch(_ state: inout State) -> Effect<Action> {
        // 受信中や待機中の講義を取得すると、その結果を上書きしてしまう（§4.6）
        guard state.activity == .idle else { return .none }
        state.fetchError = nil
        state.activity = .fetching
        return .run { [apiClient, id = state.id] send in
            do {
                await send(.fetchSucceeded(try await apiClient.course(id)))
            } catch {
                await send(.fetchFailed(error))
            }
        }
        .cancellable(id: CancelID.activity)
    }

    private func reload(_ state: State) -> Effect<Action> {
        .run { [apiClient, id = state.id] send in
            do {
                await send(.reloadSucceeded(try await apiClient.course(id)))
            } catch {
                await send(.reloadFailed(error))
            }
        }
        .cancellable(id: CancelID.activity)
    }

    private func startLectureIfNeeded(_ state: inout State) -> Effect<Action> {
        guard state.shouldStartLecture else { return .none }
        return startStream(&state, replacingMessageID: nil) { [apiClient, id = state.id] in
            apiClient.streamLecture(id)
        }
    }

    private func send(_ state: inout State) -> Effect<Action> {
        guard state.canSend, let stepID = state.conversationStepID else { return .none }
        let text = state.trimmedDraft
        // サーバーの発言に置き換わるまでの仮の発言（§4.8）
        state.appendMessage(
            ApiMessage(id: "local-\(uuid().uuidString)", stepId: stepID, role: .user, content: text, interrupted: false)
        )
        state.draft = ""
        return startStream(&state, replacingMessageID: nil) { [apiClient, id = state.id] in
            apiClient.sendMessage(id, text)
        }
    }

    private func regenerate(_ state: inout State) -> Effect<Action> {
        guard state.canRegenerate else { return .none }
        let replacingMessageID = state.lastConversationMessage.flatMap { $0.interrupted ? $0.id : nil }
        return startStream(&state, replacingMessageID: replacingMessageID) { [apiClient, id = state.id] in
            apiClient.regenerate(id)
        }
    }

    private func startStream(
        _ state: inout State,
        replacingMessageID: ApiMessage.ID?,
        makeStream: @escaping @Sendable () -> AsyncThrowingStream<LectureStreamLine, any Error>
    ) -> Effect<Action> {
        state.streamErrorMessage = nil
        state.activity = .streaming(text: "", replacingMessageID: replacingMessageID)
        return .run { send in
            do {
                for try await line in makeStream() {
                    await send(.streamLineReceived(line))
                    switch line {
                    case .delta: continue
                    case .done, .error: return
                    }
                }
                await send(.streamEndedWithoutDone)
            } catch {
                await send(.streamFailed(error))
            }
        }
        .cancellable(id: CancelID.activity)
    }

    private func receive(_ line: LectureStreamLine, into state: inout State) -> Effect<Action> {
        guard case let .streaming(text, replacingMessageID) = state.activity else { return .none }
        switch line {
        case let .delta(delta):
            state.activity = .streaming(text: text + delta, replacingMessageID: replacingMessageID)
            return .none

        case let .done(message):
            if let replacingMessageID {
                state.replaceMessage(id: replacingMessageID, with: message)
            } else {
                state.appendMessage(message)
            }
            state.activity = .idle
            return .send(.delegate(.usageRefreshRequested))

        case .error:
            // 行の message はサーバー内部のエラー文なので出さない（§4.9）
            return failStream(&state, message: Self.streamInterruptedMessage)
        }
    }

    private func failStream(_ state: inout State, message: String) -> Effect<Action> {
        guard case let .streaming(text, replacingMessageID) = state.activity else { return .none }
        state.streamErrorMessage = message
        // 途中の文字が隠した発言の後継になる。文字が無ければ、隠した発言を表示に戻すため消さない
        if let replacingMessageID, !text.isEmpty {
            state.removeMessage(id: replacingMessageID)
        }
        state.activity = .reloading(partialText: text.isEmpty ? nil : text)
        return .merge(
            .send(.delegate(.usageRefreshRequested)),
            reload(state)
        )
    }

    private func completeStep(_ state: inout State) -> Effect<Action> {
        guard state.canCompleteStep, let stepID = state.detail?.currentStepId else { return .none }
        state.stepCompletionErrorMessage = nil
        state.activity = .completingStep
        return .run { [apiClient, id = state.id] send in
            do {
                await send(.stepCompletionSucceeded(try await apiClient.completeStep(id, stepID)))
            } catch {
                await send(.stepCompletionFailed(error))
            }
        }
        .cancellable(id: CancelID.activity)
    }
}

extension LectureFeature.State {
    /// §4.7 の条件
    var shouldStartLecture: Bool {
        guard activity == .idle, streamErrorMessage == nil, let detail, detail.summary.status == .ready else { return false }
        guard detail.currentStepId != nil else { return false }
        return conversationStepMessages.isEmpty
    }

    /// §3.2
    var displayedStatus: CourseStatus {
        detail?.summary.status ?? summary.status
    }

    var isFetching: Bool {
        activity == .fetching
    }

    var isStreaming: Bool {
        if case .streaming = activity { true } else { false }
    }

    var isCompletingStep: Bool {
        activity == .completingStep
    }

    var isAllStepsCompleted: Bool {
        guard let detail else { return false }
        return detail.currentStepId == nil && !detail.steps.isEmpty
    }

    var currentStep: ApiStep? {
        detail?.steps.first { $0.id == detail?.currentStepId }
    }

    var isLastStep: Bool {
        currentStep != nil && currentStep?.id == detail?.steps.last?.id
    }

    var completedStepCount: Int {
        detail?.steps.count { $0.status == .completed } ?? 0
    }

    /// §3.2 の進捗パネルを折りたたんだときの1行
    var progressTitle: String? {
        guard let detail else { return nil }
        if isAllStepsCompleted { return "全ステップ完了" }
        return currentStep.map { "ステップ \($0.orderIndex) / \(detail.steps.count)・\($0.title)" }
    }

    /// 読み直しの間も出すが、押せない（§3.2）
    var showsCompleteStepButton: Bool {
        currentStep != nil && !isStreaming && !conversationStepMessages.isEmpty
    }

    /// §4.6
    var isStatusOutdated: Bool {
        detail.map { $0.summary.status != summary.status } ?? false
    }

    var canSend: Bool {
        activity == .idle && conversationStepID != nil && !trimmedDraft.isEmpty
    }

    var canCompleteStep: Bool {
        activity == .idle && detail?.currentStepId != nil && !conversationStepMessages.isEmpty
    }

    /// §4.13
    var canRegenerate: Bool {
        guard activity == .idle, let detail else { return false }
        if hasRegenerationTargetInConversation { return true }
        return detail.currentStepId != nil && conversationStepMessages.isEmpty && streamErrorMessage != nil
    }

    /// 対象が会話にあるときは、会話の中の文言と重なるため出さない（§3.2）
    var visibleStreamError: String? {
        hasRegenerationTargetInConversation ? nil : streamErrorMessage
    }

    var conversationContent: ConversationContent? {
        guard let detail else { return nil }
        let unansweredQuestionID = canRegenerate ? lastConversationMessage.flatMap { $0.role == .user ? $0.id : nil } : nil
        var items: [ConversationItem] = []
        var dividedStepID: ApiStep.ID?

        func appendDividerIfNeeded(stepID: ApiStep.ID?) {
            guard let stepID, stepID != dividedStepID else { return }
            dividedStepID = stepID
            guard let step = detail.steps.first(where: { $0.id == stepID }) else { return }
            items.append(.divider(id: "divider-\(step.id)", label: "ステップ \(step.orderIndex)・\(step.title)"))
        }

        for message in detail.messages where message.id != hiddenMessageID {
            appendDividerIfNeeded(stepID: message.stepId)
            switch message.role {
            case .user:
                items.append(.user(id: message.id, text: message.content))
            case .assistant:
                items.append(.assistant(id: message.id, markdown: message.content))
            }
            if message.interrupted {
                items.append(.notice(id: "interrupted-\(message.id)", text: "応答が途中で途切れました"))
            }
            if message.id == unansweredQuestionID {
                items.append(.notice(id: "unanswered-\(message.id)", text: "応答を取得できませんでした"))
            }
        }

        if streamingText != nil {
            appendDividerIfNeeded(stepID: conversationStepID)
        }
        return ConversationContent(id: id, items: items, streaming: streamingText)
    }

    private var streamingText: String? {
        switch activity {
        case let .streaming(text, _): text
        case let .reloading(partialText): partialText
        case .idle, .fetching, .completingStep: nil
        }
    }

    private var hiddenMessageID: ApiMessage.ID? {
        guard case let .streaming(_, replacingMessageID) = activity else { return nil }
        return replacingMessageID
    }

    /// 全ステップ完了後の発言は最後のステップに紐づく（Web §4.2.4、Q-32）
    var conversationStepID: ApiStep.ID? {
        detail?.currentStepId ?? detail?.steps.last?.id
    }

    private var conversationStepMessages: [ApiMessage] {
        detail?.messages.filter { $0.stepId == conversationStepID } ?? []
    }

    var lastConversationMessage: ApiMessage? {
        conversationStepMessages.last
    }

    private var hasRegenerationTargetInConversation: Bool {
        let messages = conversationStepMessages
        guard let last = messages.last, last.role == .user || last.interrupted else { return false }
        // 全ステップ完了後に講義本文はやり直せない（§4.13）
        if detail?.currentStepId != nil { return true }
        return last.role == .user || messages.dropLast().last?.role == .user
    }

    fileprivate var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate mutating func replaceCourse(with detail: CourseDetail) {
        self.detail = detail
        summary = detail.summary
        activity = .idle
    }

    fileprivate mutating func appendMessage(_ message: ApiMessage) {
        updateMessages { $0.append(message) }
    }

    fileprivate mutating func replaceMessage(id: ApiMessage.ID, with message: ApiMessage) {
        updateMessages { messages in
            if let index = messages.firstIndex(where: { $0.id == id }) {
                messages[index] = message
            } else {
                messages.append(message)
            }
        }
    }

    fileprivate mutating func removeMessage(id: ApiMessage.ID) {
        updateMessages { $0.removeAll { $0.id == id } }
    }

    /// §4.9
    fileprivate mutating func keepPartialTextAsInterruptedMessage(id: ApiMessage.ID) {
        guard case let .reloading(partialText?) = activity, let conversationStepID else { return }
        appendMessage(ApiMessage(id: id, stepId: conversationStepID, role: .assistant, content: partialText, interrupted: true))
    }

    private mutating func updateMessages(_ update: (inout [ApiMessage]) -> Void) {
        guard let detail else { return }
        var messages = detail.messages
        update(&messages)
        self.detail = CourseDetail(
            summary: detail.summary,
            currentStepId: detail.currentStepId,
            steps: detail.steps,
            messages: messages
        )
    }
}
