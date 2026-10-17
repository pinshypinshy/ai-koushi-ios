//
//  APIClientLiveTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import APIClient
@testable import APIClientLive
import Foundation
import Models
import os
import Testing

// StubURLProtocol の応答はテスト同士で共有するため、並列に実行しない
@Suite(.serialized)
struct APIClientLiveTests {
    let baseURL = APIClient.productionBaseURL
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
    }
    
    private func makeCookie(domain: String) throws -> HTTPCookie {
        try #require(
            HTTPCookie(properties: [.name: "ak_session", .value: "token", .domain: domain, .path: "/", .secure: "TRUE"])
        )
    }
}

/// サーバーの応答と同じ形。selected など Models で宣言していない項目も含め、無視されることを確かめる
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
    "selected": { "id": "c1", "steps": [], "messages": [] },
    "usage": { "costUsd": 0.42, "costLimitUsd": 3, "courses": 1, "courseLimit": 2, "periodStart": 1759244400000 }
}
"""

/// URLSession が送る直前で要求を横取りし、決まった応答を返す
final class StubURLProtocol: URLProtocol {
    private enum Outcome {
        case response(status: Int, body: Data)
        case failure(URLError)
    }
    
    private struct State {
        var outcome: Outcome?
        var lastRequest: URLRequest?
        var lastRequestBody: Data?
    }
    
    private static let state = OSAllocatedUnfairLock(initialState: State())
    
    static var lastRequest: URLRequest? { state.withLock { $0.lastRequest } }
    static var lastRequestBody: Data? { state.withLock { $0.lastRequestBody } }
    
    static func reset() { state.withLock { $0 = State() } }
    static func respond(status: Int, body: Data) { state.withLock { $0.outcome = .response(status: status, body: body) } }
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
        case let .response(status, data):
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
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
