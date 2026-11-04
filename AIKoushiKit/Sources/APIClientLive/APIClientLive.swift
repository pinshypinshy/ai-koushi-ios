//
//  APIClientLive.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import APIClient
import AppConfig
import ComposableArchitecture
import Foundation
import Models

extension APIClient: DependencyKey {
    public static let liveValue = APIClient.live(baseURL: ServerURL.production, session: .shared)
    
    /// テストで URLSession を差し替えるため、組み立てを関数に分けている
    static func live(baseURL: URL, session: URLSession) -> APIClient {
        APIClient(
            bootstrap: {
                let data = try await send(makeRequest(baseURL, "GET", "api/bootstrap"), session: session)
                return try decode(BootstrapResponse.self, from: data)
            },
            guestLogin: { loginId, password in
                // JSONEncoder が失敗するのは NaN などの数値で、文字列だけの構造体では起きないため try! を使っている
                let body = try! JSONEncoder().encode(GuestLoginRequest(loginId: loginId, password: password))
                _ = try await send(makeRequest(baseURL, "POST", "auth/guest", body: body), session: session)
            },
            logout: {
                defer { deleteCookies(for: baseURL, in: session) }
                _ = try await send(makeRequest(baseURL, "POST", "auth/logout"), session: session)
            },
            course: { id in
                let data = try await send(makeRequest(baseURL, "GET", "api/courses/\(id)"), session: session)
                return try decode(CourseDetail.self, from: data)
            },
            streamLecture: { courseId in
                stream(makeRequest(baseURL, "POST", "api/courses/\(courseId)/lecture"), session: session)
            },
            sendMessage: { courseId, text in
                // guestLogin と同じ理由で try! を使っている
                let body = try! JSONEncoder().encode(SendMessageRequest(text: text))
                return stream(makeRequest(baseURL, "POST", "api/courses/\(courseId)/messages", body: body), session: session)
            },
            regenerate: { courseId in
                stream(makeRequest(baseURL, "POST", "api/courses/\(courseId)/regenerate"), session: session)
            },
            completeStep: { courseId, stepId in
                let data = try await send(makeRequest(baseURL, "POST", "api/courses/\(courseId)/steps/\(stepId)/complete"), session: session)
                return try decode(CourseDetail.self, from: data)
            },
            usage: {
                let data = try await send(makeRequest(baseURL, "GET", "api/usage"), session: session)
                return try decode(UsageSummary.self, from: data)
            }
        )
    }
    
    private static func makeRequest(_ baseURL: URL, _ method: String, _ path: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 15)  // §5
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
    
    private static func send(_ request: URLRequest, session: URLSession) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw connectionError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.decoding
        }
        guard (200..<300).contains(http.statusCode) else {
            throw httpError(status: http.statusCode, data: data)
        }
        return data
    }

    private static func stream(_ request: URLRequest, session: URLSession) -> AsyncThrowingStream<LectureStreamLine, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw APIClientError.decoding
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                        }
                        throw httpError(status: http.statusCode, data: data)
                    }
                    // bytes.lines は U+2028 でも行を分ける。サーバーの JSON.stringify はこの文字をそのまま出すので、LF だけで分ける
                    var line = Data()
                    for try await byte in bytes {
                        guard byte == UInt8(ascii: "\n") else {
                            line.append(byte)
                            continue
                        }
                        continuation.yield(try decode(LectureStreamLine.self, from: line))
                        line.removeAll(keepingCapacity: true)
                    }
                    if !line.isEmpty {
                        continuation.yield(try decode(LectureStreamLine.self, from: line))
                    }
                    continuation.finish()
                } catch let error as APIClientError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: connectionError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIClientError.decoding
        }
    }

    private static func connectionError(_ error: any Error) -> any Error {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return CancellationError()
        }
        return APIClientError.network
    }

    private static func httpError(status: Int, data: Data) -> APIClientError {
        // JSON でない本文（Cloudflare のエラー画面など）も届くため、読めなければ body は nil にする
        let body = try? JSONDecoder().decode(ApiError.self, from: data)
        return APIClientError.http(status: status, body: body)
    }
    
    private static func deleteCookies(for baseURL: URL, in session: URLSession) {
        guard let storage = session.configuration.httpCookieStorage else { return }
        for cookie in storage.cookies(for: baseURL) ?? [] {
            storage.deleteCookie(cookie)
        }
    }
}

private struct GuestLoginRequest: Encodable {
    let loginId: String
    let password: String
}

private struct SendMessageRequest: Encodable {
    let text: String
}
