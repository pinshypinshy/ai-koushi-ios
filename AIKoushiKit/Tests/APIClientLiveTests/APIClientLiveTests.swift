//
//  APIClientLiveTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import APIClient
@testable import APIClientLive
import AppConfig
import Foundation
import Models
import os
import Testing

// StubURLProtocol の応答はテスト同士で共有するため、並列に実行しない
@Suite(.serialized)
struct APIClientLiveTests {
    let baseURL = ServerURL.production
    let session: URLSession
    let client: APIClient
    
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = APIClient.live(baseURL: baseURL, session: session)
        StubURLProtocol.reset()
    }
    
    // MARK: - bootstrap
    
    @Test func bootstrapDecodesServerResponse() async throws {
        StubURLProtocol.respond(status: 200, body: Data(bootstrapJSON.utf8))
        
        let response = try await client.bootstrap()
        
        #expect(
            response == BootstrapResponse(
                user: ApiUser(id: "u1", email: "guest-01", displayName: "ゲスト"),
                courses: [
                    CourseSummary(
                        id: "c1", title: "Git入門", status: .ready, quizStatus: .failed, phase: nil,
                        errorMessage: nil, totalSteps: 8, completedSteps: 3, updatedAt: 1_760_000_000_000
                    ),
                    CourseSummary(
                        id: "c2", title: "線形代数", status: .generating, quizStatus: .pending, phase: .outline,
                        errorMessage: nil, totalSteps: 0, completedSteps: 0, updatedAt: 1_760_000_100_000
                    ),
                ],
                selected: CourseDetail(
                    summary: CourseSummary(
                        id: "c1", title: "Git入門", status: .ready, quizStatus: .failed, phase: nil,
                        errorMessage: nil, totalSteps: 2, completedSteps: 1, updatedAt: 1_760_000_000_000
                    ),
                    currentStepId: "s2",
                    steps: [
                        ApiStep(id: "s1", orderIndex: 1, title: "リポジトリ", status: .completed),
                        ApiStep(id: "s2", orderIndex: 2, title: "コミット", status: .inProgress),
                    ],
                    messages: [
                        ApiMessage(id: "m1", stepId: "s2", role: .assistant, content: "コミットとは", interrupted: true),
                        ApiMessage(id: "m2", stepId: "s2", role: .user, content: "なぜ必要？", interrupted: false),
                    ]
                ),
                usage: UsageSummary(costUsd: 0.42, costLimitUsd: 3, courses: 1, courseLimit: 2, periodStart: 1_759_244_400_000)
            )
        )
        #expect(StubURLProtocol.lastRequest?.httpMethod == "GET")
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/api/bootstrap")
    }
    
    @Test func bootstrapReturnsHTTPErrorWithServerMessage() async {
        StubURLProtocol.respond(status: 401, body: Data(#"{"error":"unauthorized","message":"ログインが必要です"}"#.utf8))
        
        await #expect(throws: APIClientError.http(status: 401, body: ApiError(error: "unauthorized", message: "ログインが必要です"))) {
            try await client.bootstrap()
        }
    }
    
    @Test func bootstrapReturnsHTTPErrorWithoutBodyWhenNotJSON() async {
        StubURLProtocol.respond(status: 500, body: Data("<html>error</html>".utf8))
        
        await #expect(throws: APIClientError.http(status: 500, body: nil)) {
            try await client.bootstrap()
        }
    }
    
    @Test func bootstrapReturnsDecodingErrorForBrokenJSON() async {
        StubURLProtocol.respond(status: 200, body: Data(#"{"user":"#.utf8))
        
        await #expect(throws: APIClientError.decoding) {
            try await client.bootstrap()
        }
    }
    
    @Test func bootstrapReturnsNetworkErrorWhenOffline() async {
        StubURLProtocol.fail(with: URLError(.notConnectedToInternet))
        
        await #expect(throws: APIClientError.network) {
            try await client.bootstrap()
        }
    }
    
    @Test func cancellationIsNotTreatedAsNetworkError() async {
        StubURLProtocol.fail(with: URLError(.cancelled))
        
        await #expect(throws: CancellationError.self) {
            try await client.bootstrap()
        }
    }
    
    // MARK: - guestLogin
    
    @Test func guestLoginSendsLoginIdAndPassword() async throws {
        StubURLProtocol.respond(status: 204, body: Data())
        
        try await client.guestLogin(loginId: "guest-01", password: "pass")
        
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/auth/guest")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: try #require(StubURLProtocol.lastRequestBody)) as? [String: String]
        #expect(body == ["loginId": "guest-01", "password": "pass"])
    }
    
    @Test func guestLoginReturnsHTTPErrorWhenRateLimited() async {
        StubURLProtocol.respond(status: 429, body: Data(#"{"error":"too_many_requests","message":"しばらくしてから再度お試しください"}"#.utf8))
        
        await #expect(
            throws: APIClientError.http(status: 429, body: ApiError(error: "too_many_requests", message: "しばらくしてから再度お試しください"))
        ) {
            try await client.guestLogin(loginId: "guest-01", password: "pass")
        }
    }
    
    // MARK: - logout
    
    @Test func logoutDeletesCookiesOfProductionDomainOnly() async throws {
        let storage = try #require(session.configuration.httpCookieStorage)
        storage.setCookie(try makeCookie(domain: "ai-koushi.yuki-hiraishi.com"))
        storage.setCookie(try makeCookie(domain: "example.com"))
        StubURLProtocol.respond(status: 204, body: Data())
        
        try await client.logout()
        
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/auth/logout")
        #expect(storage.cookies(for: baseURL)?.isEmpty ?? true)
        #expect(storage.cookies?.map(\.domain) == ["example.com"])
    }
    
    @Test func logoutDeletesCookieEvenWhenOffline() async throws {
        let storage = try #require(session.configuration.httpCookieStorage)
        storage.setCookie(try makeCookie(domain: "ai-koushi.yuki-hiraishi.com"))
        StubURLProtocol.fail(with: URLError(.notConnectedToInternet))
        
        await #expect(throws: APIClientError.network) {
            try await client.logout()
        }
        #expect(storage.cookies(for: baseURL)?.isEmpty ?? true)
    }
    
    // MARK: - course

    @Test func courseDecodesServerResponse() async throws {
        StubURLProtocol.respond(status: 200, body: Data(courseJSON.utf8))

        let course = try await client.course(id: "c1")

        #expect(course == expectedCourse)
        #expect(StubURLProtocol.lastRequest?.httpMethod == "GET")
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/api/courses/c1")
    }

    @Test func courseReturnsHTTPErrorWhenNotFound() async {
        StubURLProtocol.respond(status: 404, body: Data(#"{"error":"not_found","message":"講義が見つかりません"}"#.utf8))

        await #expect(throws: APIClientError.http(status: 404, body: ApiError(error: "not_found", message: "講義が見つかりません"))) {
            try await client.course(id: "c1")
        }
    }

    // MARK: - 受信（streamLecture・sendMessage・regenerate）

    @Test func streamLectureYieldsLinesInOrder() async throws {
        StubURLProtocol.respond(status: 200, body: ndjson(#"{"delta":"コミット"}"#, #"{"delta":"とは"}"#, doneLine))

        let lines = try await collect(client.streamLecture(courseId: "c1"))

        #expect(lines == [.delta("コミット"), .delta("とは"), .done(doneMessage)])
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/api/courses/c1/lecture")
    }

    @Test func sendMessageSendsText() async throws {
        StubURLProtocol.respond(status: 200, body: ndjson(doneLine))

        let lines = try await collect(client.sendMessage(courseId: "c1", text: "なぜ必要？"))

        #expect(lines == [.done(doneMessage)])
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/api/courses/c1/messages")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: try #require(StubURLProtocol.lastRequestBody)) as? [String: String]
        #expect(body == ["text": "なぜ必要？"])
    }

    @Test func regenerateRequestsRegeneratePath() async throws {
        StubURLProtocol.respond(status: 200, body: ndjson(doneLine))

        let lines = try await collect(client.regenerate(courseId: "c1"))

        #expect(lines == [.done(doneMessage)])
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/api/courses/c1/regenerate")
    }

    @Test func streamYieldsErrorLineWithoutThrowing() async throws {
        StubURLProtocol.respond(status: 200, body: ndjson(#"{"delta":"途中"}"#, #"{"error":{"message":"失敗","partialSaved":true}}"#))

        let lines = try await collect(client.streamLecture(courseId: "c1"))

        #expect(lines == [.delta("途中"), .error(message: "失敗")])
    }

    @Test func streamFinishesWithoutThrowingWhenDoneIsMissing() async throws {
        StubURLProtocol.respond(status: 200, body: ndjson(#"{"delta":"途中"}"#))

        let lines = try await collect(client.streamLecture(courseId: "c1"))

        #expect(lines == [.delta("途中")])
    }

    @Test func streamJoinsLineSplitAcrossChunks() async throws {
        let data = ndjson(#"{"delta":"日本語"}"#, #"{"delta":"続き"}"#)
        // 11バイト目は「日」の途中。2つ目の区切りは次の行の途中
        let chunks = [Data(data.prefix(11)), Data(data.dropFirst(11).dropLast(5)), Data(data.suffix(5))]
        StubURLProtocol.respond(status: 200, chunks: chunks)

        let lines = try await collect(client.streamLecture(courseId: "c1"))

        #expect(lines == [.delta("日本語"), .delta("続き")])
    }

    @Test func streamDoesNotSplitLineAtUnicodeLineSeparator() async throws {
        StubURLProtocol.respond(status: 200, body: ndjson("{\"delta\":\"前\u{2028}後\"}"))

        let lines = try await collect(client.streamLecture(courseId: "c1"))

        #expect(lines == [.delta("前\u{2028}後")])
    }

    @Test func streamReadsLastLineWithoutNewline() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"delta":"末尾"}"#.utf8))

        let lines = try await collect(client.streamLecture(courseId: "c1"))

        #expect(lines == [.delta("末尾")])
    }

    @Test func streamThrowsHTTPErrorWithServerMessage() async {
        StubURLProtocol.respond(status: 403, body: Data(#"{"error":"limit_exceeded","message":"この講義の生成量が上限に達しました"}"#.utf8))

        await #expect(
            throws: APIClientError.http(status: 403, body: ApiError(error: "limit_exceeded", message: "この講義の生成量が上限に達しました"))
        ) {
            try await collect(client.streamLecture(courseId: "c1"))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func streamThrowsNetworkErrorAfterYieldingReceivedLines() async {
        StubURLProtocol.respond(status: 200, chunks: [ndjson(#"{"delta":"途中"}"#)], thenFailWhenReleased: URLError(.networkConnectionLost))

        var lines: [LectureStreamLine] = []
        var thrown: (any Error)?
        do {
            for try await line in client.streamLecture(courseId: "c1") {
                lines.append(line)
                StubURLProtocol.releaseFailure()
            }
        } catch {
            thrown = error
        }

        #expect(lines == [.delta("途中")])
        #expect(thrown as? APIClientError == .network)
    }

    @Test func streamThrowsDecodingErrorForUnreadableLine() async {
        StubURLProtocol.respond(status: 200, body: ndjson(#"{"unknown":1}"#))

        await #expect(throws: APIClientError.decoding) {
            try await collect(client.streamLecture(courseId: "c1"))
        }
    }

    @Test func streamThrowsCancellationErrorWhenCancelled() async {
        StubURLProtocol.fail(with: URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            try await collect(client.streamLecture(courseId: "c1"))
        }
    }

    // MARK: - completeStep

    @Test func completeStepDecodesServerResponse() async throws {
        StubURLProtocol.respond(status: 200, body: Data(courseJSON.utf8))

        let course = try await client.completeStep(courseId: "c1", stepId: "s2")

        #expect(course == expectedCourse)
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/api/courses/c1/steps/s2/complete")
    }

    // MARK: - usage

    @Test func usageDecodesServerResponse() async throws {
        StubURLProtocol.respond(
            status: 200,
            body: Data(#"{"costUsd":0.42,"costLimitUsd":3,"courses":1,"courseLimit":2,"periodStart":1759244400000}"#.utf8)
        )

        let usage = try await client.usage()

        #expect(usage == UsageSummary(costUsd: 0.42, costLimitUsd: 3, courses: 1, courseLimit: 2, periodStart: 1_759_244_400_000))
        #expect(StubURLProtocol.lastRequest?.httpMethod == "GET")
        #expect(StubURLProtocol.lastRequest?.url?.path() == "/api/usage")
    }

    // MARK: - 待ち時間（§5）

    @Test func everyRequestTimesOutAfter15Seconds() async throws {
        StubURLProtocol.respond(status: 200, body: Data(bootstrapJSON.utf8))
        _ = try await client.bootstrap()
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        StubURLProtocol.respond(status: 204, body: Data())
        try await client.guestLogin(loginId: "guest-01", password: "pass")
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        try await client.logout()
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        StubURLProtocol.respond(status: 200, body: Data(courseJSON.utf8))
        _ = try await client.course(id: "c1")
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        _ = try await client.completeStep(courseId: "c1", stepId: "s2")
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        StubURLProtocol.respond(status: 200, body: ndjson(doneLine))
        _ = try await collect(client.streamLecture(courseId: "c1"))
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        _ = try await collect(client.sendMessage(courseId: "c1", text: "質問"))
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        _ = try await collect(client.regenerate(courseId: "c1"))
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)

        StubURLProtocol.respond(
            status: 200,
            body: Data(#"{"costUsd":0,"costLimitUsd":3,"courses":0,"courseLimit":2,"periodStart":0}"#.utf8)
        )
        _ = try await client.usage()
        #expect(StubURLProtocol.lastRequest?.timeoutInterval == 15)
    }

    @discardableResult
    private func collect(_ stream: AsyncThrowingStream<LectureStreamLine, any Error>) async throws -> [LectureStreamLine] {
        var lines: [LectureStreamLine] = []
        for try await line in stream {
            lines.append(line)
        }
        return lines
    }

    private func ndjson(_ lines: String...) -> Data {
        Data(lines.map { $0 + "\n" }.joined().utf8)
    }

    private func makeCookie(domain: String) throws -> HTTPCookie {
        try #require(
            HTTPCookie(properties: [.name: "ak_session", .value: "token", .domain: domain, .path: "/", .secure: "TRUE"])
        )
    }
}

private let doneLine = #"{"done":{"id":"m1","stepId":"s1","role":"assistant","content":"本文","createdAt":1760000060000,"interrupted":false}}"#
private let doneMessage = ApiMessage(id: "m1", stepId: "s1", role: .assistant, content: "本文", interrupted: false)

private let courseJSON = """
{
    "id": "c1", "title": "Git入門", "status": "ready", "quizStatus": "failed", "phase": null,
    "errorMessage": null, "totalSteps": 1, "completedSteps": 1, "updatedAt": 1760000000000,
    "currentStepId": null,
    "steps": [
        {
            "id": "s1", "orderIndex": 1, "title": "リポジトリ", "objective": "リポジトリを作れる",
            "keyPoints": [], "sourceRef": null, "status": "completed", "completedAt": 1760000050000
        }
    ],
    "messages": []
}
"""
private let expectedCourse = CourseDetail(
    summary: CourseSummary(
        id: "c1", title: "Git入門", status: .ready, quizStatus: .failed, phase: nil,
        errorMessage: nil, totalSteps: 1, completedSteps: 1, updatedAt: 1_760_000_000_000
    ),
    currentStepId: nil,
    steps: [ApiStep(id: "s1", orderIndex: 1, title: "リポジトリ", status: .completed)],
    messages: []
)

/// サーバーの応答と同じ形。objective など Models で宣言していない項目も含め、無視されることを確かめる
private let bootstrapJSON = """
{
    "user": { "id": "u1", "email": "guest-01", "displayName": "ゲスト" },
    "courses": [
        {
            "id": "c1", "title": "Git入門", "status": "ready", "quizStatus": "failed", "phase": null,
            "errorMessage": null, "totalSteps": 8, "completedSteps": 3, "updatedAt": 1760000000000
        },
        {
            "id": "c2", "title": "線形代数", "status": "generating", "quizStatus": "pending", "phase": "outline",
            "errorMessage": null, "totalSteps": 0, "completedSteps": 0, "updatedAt": 1760000100000
        }
    ],
    "selected": {
        "id": "c1", "title": "Git入門", "status": "ready", "quizStatus": "failed", "phase": null,
        "errorMessage": null, "totalSteps": 2, "completedSteps": 1, "updatedAt": 1760000000000,
        "currentStepId": "s2",
        "steps": [
            {
                "id": "s1", "orderIndex": 1, "title": "リポジトリ", "objective": "リポジトリを作れる",
                "keyPoints": ["init", "clone"], "sourceRef": "1章", "status": "completed", "completedAt": 1760000050000
            },
            {
                "id": "s2", "orderIndex": 2, "title": "コミット", "objective": "変更を記録できる",
                "keyPoints": [], "sourceRef": null, "status": "in_progress", "completedAt": null
            }
        ],
        "messages": [
            {
                "id": "m1", "stepId": "s2", "role": "assistant", "content": "コミットとは",
                "createdAt": 1760000060000, "interrupted": true
            },
            {
                "id": "m2", "stepId": "s2", "role": "user", "content": "なぜ必要？",
                "createdAt": 1760000070000, "interrupted": false
            }
        ]
    },
    "usage": { "costUsd": 0.42, "costLimitUsd": 3, "courses": 1, "courseLimit": 2, "periodStart": 1759244400000 }
}
"""

/// URLSession が送る直前で要求を横取りし、決まった応答を返す
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private enum Outcome {
        case response(status: Int, headers: [String: String]?, chunks: [Data], failure: URLError?)
        case failure(URLError)
    }
    
    private struct HeldFailure: Sendable {
        let loading: StubURLProtocol
        let error: URLError
    }
    
    private struct State {
        var outcome: Outcome?
        var heldFailure: HeldFailure?
        var lastRequest: URLRequest?
        var lastRequestBody: Data?
    }
    
    private static let state = OSAllocatedUnfairLock(initialState: State())
    
    static var lastRequest: URLRequest? { state.withLock { $0.lastRequest } }
    static var lastRequestBody: Data? { state.withLock { $0.lastRequestBody } }
    
    static func reset() { state.withLock { $0 = State() } }
    static func respond(status: Int, body: Data) {
        state.withLock { $0.outcome = .response(status: status, headers: nil, chunks: [body], failure: nil) }
    }
    /// server/src/routes/lecture.ts と同じヘッダーを付ける。無いと URLSession が受け手へ渡すのを遅らせ、届いた分を読めない
    static func respond(status: Int, chunks: [Data], thenFailWhenReleased failure: URLError? = nil) {
        let headers = ["Content-Type": "application/x-ndjson; charset=utf-8", "X-Content-Type-Options": "nosniff"]
        state.withLock { $0.outcome = .response(status: status, headers: headers, chunks: chunks, failure: failure) }
    }
    static func releaseFailure() {
        let held = state.withLock { state in
            defer { state.heldFailure = nil }
            return state.heldFailure
        }
        guard let held else { return }
        held.loading.client?.urlProtocol(held.loading, didFailWithError: held.error)
    }
    static func fail(with error: URLError) { state.withLock { $0.outcome = .failure(error) } }
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        // URLProtocol に届く要求では、本文が httpBody ではなく httpBodyStream に入っている
        let request = self.request
        let body = request.httpBodyStream.map(Self.readAll)
        let outcome = Self.state.withLock {
            $0.lastRequest = request
            $0.lastRequestBody = body
            return $0.outcome
        }
        switch outcome {
        case let .response(status, headers, chunks, failure):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks {
                client?.urlProtocol(self, didLoad: chunk)
            }
            if let failure {
                // 受け手が読む前に失敗させないよう、読み終えたテストが releaseFailure で失敗させる
                Self.state.withLock { $0.heldFailure = HeldFailure(loading: self, error: failure) }
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            Issue.record("応答が設定されていない")
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
        }
    }
    
    override func stopLoading() {}
    
    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
