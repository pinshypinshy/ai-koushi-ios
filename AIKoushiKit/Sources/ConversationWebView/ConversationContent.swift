//
//  ConversationContent.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

public struct ConversationContent: Equatable, Sendable {
    /// 変わったら全体を描き直し、末尾を表示する（§3.2「講義を開いたとき」）
    public var id: String
    public var items: [ConversationItem]
    /// nil は受信していない、空文字はまだ1文字も届いていない（§3.2）
    public var streaming: String?

    public init(id: String, items: [ConversationItem], streaming: String?) {
        self.id = id
        self.items = items
        self.streaming = streaming
    }
}

public enum ConversationItem: Equatable, Sendable {
    case divider(id: String, label: String)
    case assistant(id: String, markdown: String)
    case user(id: String, text: String)
}

// JSON の形は WebRenderer/src/commands.ts の ConversationItem と対になる
extension ConversationItem: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, id, label, markdown, text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .divider(id, label):
            try container.encode("divider", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(label, forKey: .label)
        case let .assistant(id, markdown):
            try container.encode("assistant", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(markdown, forKey: .markdown)
        case let .user(id, text):
            try container.encode("user", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(text, forKey: .text)
        }
    }
}
