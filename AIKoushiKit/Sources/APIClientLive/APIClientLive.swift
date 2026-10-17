//
//  APIClientLive.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import APIClient
import ComposableArchitecture
import Foundation
import Models

extension APIClient: DependencyKey {
    // 固定の文字列リテラルで、URL として解釈できないことが無いため強制アンラップしている
    static let productionBaseURL = URL(string: "https://ai-koushi.yuki-hiraishi.com")!
    
    public static let liveValue = APIClient.live(baseURL: productionBaseURL, session: .shared)
    
    /// テストで URLSession を差し替えるため、組み立てを関数に分けている
    static func live(baseURL: URL, session: URLSession) -> APIClient {
        APIClient(
            bootstrap: {
                let data = try await send(makeRequest(baseURL, "GET", "api/bootstrap"), session: session)
                do {
                    return try JSONDecoder().decode(BootstrapResponse.self, from: data)
                } catch {
                    throw APIClientError.decoding
                }
            },
            guestLogin: { loginId, password in
                // JSONEncoder が失敗するのは NaN などの数値で、文字列だけの構造体では起きないため try! を使っている
                let body = try! JSONEncoder().encode(GuestLoginRequest(loginId: loginId, password: password))
                _ = try await send(makeRequest(baseURL, "POST", "auth/guest", body: body), session: session)
            },
            logout: {
                defer { deleteCookies(for: baseURL, in: session) }
                _ = try await send(makeRequest(baseURL, "POST", "auth/logout"), session: session)
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
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw APIClientError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.decoding
        }
        guard (200..<300).contains(http.statusCode) else {
            // JSON でない本文（Cloudflare のエラー画面など）も届くため、読めなければ body は nil にする
            let body = try? JSONDecoder().decode(ApiError.self, from: data)
            throw APIClientError.http(status: http.statusCode, body: body)
        }
        return data
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
