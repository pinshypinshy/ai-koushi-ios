//
//  ApiMessage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/02.
//

public enum MessageRole: String, Decodable, Equatable, Sendable {
    case user
    case assistant
}

// createdAt は画面で使わないため宣言しない（並び順はサーバーが返す順のとおり）
public struct ApiMessage: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let stepId: String
    public let role: MessageRole
    public let content: String
    public let interrupted: Bool

    public init(id: String, stepId: String, role: MessageRole, content: String, interrupted: Bool) {
        self.id = id
        self.stepId = stepId
        self.role = role
        self.content = content
        self.interrupted = interrupted
    }
}
