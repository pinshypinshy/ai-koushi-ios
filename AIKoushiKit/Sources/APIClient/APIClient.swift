//
//  APIClient.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import ComposableArchitecture
import Models

/// 投げるエラーは APIClientError と CancellationError だけ
@DependencyClient
public struct APIClient: Sendable {
    public var bootstrap: @Sendable () async throws -> BootstrapResponse
    public var guestLogin: @Sendable (_ loginId: String, _ password: String) async throws -> Void
    /// 通信の成否にかかわらず、手元の Cookie を消す（§4.5）
    public var logout: @Sendable () async throws -> Void
    public var course: @Sendable (_ id: String) async throws -> CourseDetail
    /// 403 などのエラーも、列を読む途中で投げる。`done` が届かずに列が終わることもあり、その判断は呼ぶ側が行う（§4.9）
    public var streamLecture: @Sendable (_ courseId: String) -> AsyncThrowingStream<LectureStreamLine, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
    /// エラーの扱いは streamLecture と同じ
    public var sendMessage: @Sendable (_ courseId: String, _ text: String) -> AsyncThrowingStream<LectureStreamLine, any Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }
    /// エラーの扱いは streamLecture と同じ
    public var regenerate: @Sendable (_ courseId: String) -> AsyncThrowingStream<LectureStreamLine, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
    public var completeStep: @Sendable (_ courseId: String, _ stepId: String) async throws -> CourseDetail
    public var usage: @Sendable () async throws -> UsageSummary
    public var quiz: @Sendable (_ courseId: String) async throws -> QuizResponse
    public var attempt: @Sendable (_ questionId: String, _ selectedChoiceId: String) async throws -> AttemptResult
}

extension APIClient: TestDependencyKey {
    public static let testValue = APIClient()
}

extension DependencyValues {
    public var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
