//
//  ConversationCommand.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

/// JSON の形は WebRenderer/src/commands.ts の Command と対になる
enum ConversationCommand: Equatable {
    case configure(ConversationConfiguration)
    case reset(items: [ConversationItem], streaming: String?, scrollToEnd: Bool)
    case append(items: [ConversationItem], scrollToEnd: Bool)
    case setStreaming(String?)

    static func commands(from old: ConversationContent?, to new: ConversationContent) -> [Self] {
        guard let old, old.id == new.id else {
            return [.reset(items: new.items, streaming: new.streaming, scrollToEnd: true)]
        }
        guard new.items.starts(with: old.items) else {
            return [.reset(items: new.items, streaming: new.streaming, scrollToEnd: false)]
        }

        var commands: [Self] = []
        let added = Array(new.items.dropFirst(old.items.count))
        if !added.isEmpty {
            // 利用者が発言を送ったときは末尾を表示する（§3.2）
            let containsUser = added.contains { if case .user = $0 { true } else { false } }
            commands.append(.append(items: added, scrollToEnd: containsUser))
        }
        if new.streaming != old.streaming {
            commands.append(.setStreaming(new.streaming))
        }
        return commands
    }
}

extension ConversationCommand: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, configuration, items, streaming, scrollToEnd, text
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .configure(configuration):
            try container.encode("configure", forKey: .type)
            try container.encode(configuration, forKey: .configuration)
        case let .reset(items, streaming, scrollToEnd):
            try container.encode("reset", forKey: .type)
            try container.encode(items, forKey: .items)
            // nil を省かず null として送る（JavaScript 側は null だけを受け付ける）
            try container.encode(streaming, forKey: .streaming)
            try container.encode(scrollToEnd, forKey: .scrollToEnd)
        case let .append(items, scrollToEnd):
            try container.encode("append", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encode(scrollToEnd, forKey: .scrollToEnd)
        case let .setStreaming(text):
            try container.encode("setStreaming", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }
}
