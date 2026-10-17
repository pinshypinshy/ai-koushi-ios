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
