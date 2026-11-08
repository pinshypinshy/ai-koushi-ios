//
//  ConversationCommand.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

/// JSON の形は WebRenderer/src/conversation/commands.ts の ConversationCommand と対になる
enum ConversationCommand: Equatable {
    case reset(items: [ConversationItem], streaming: String?, waitingText: String, scrollToEnd: Bool)
    case append(items: [ConversationItem], scrollToEnd: Bool)
    case setStreaming(String?)

    static func commands(from old: ConversationContent?, to new: ConversationContent) -> [Self] {
        guard let old, old.id == new.id else {
            return [.reset(items: new.items, streaming: new.streaming, waitingText: new.waitingText, scrollToEnd: true)]
        }
        // 利用者が発言を送ったときは末尾を表示する（§3.2）。
        // ID で比べると、読み直しで手元の ID がサーバーの ID に変わっただけのときも移動してしまう
        let sentMessage = userMessageCount(in: new.items) > userMessageCount(in: old.items)
        guard new.waitingText == old.waitingText, new.items.starts(with: old.items) else {
            return [.reset(items: new.items, streaming: new.streaming, waitingText: new.waitingText, scrollToEnd: sentMessage)]
        }

        var commands: [Self] = []
        let added = Array(new.items.dropFirst(old.items.count))
        if !added.isEmpty {
            commands.append(.append(items: added, scrollToEnd: sentMessage))
        }
        if new.streaming != old.streaming {
            commands.append(.setStreaming(new.streaming))
        }
        return commands
    }

    private static func userMessageCount(in items: [ConversationItem]) -> Int {
        items.count { if case .user = $0 { true } else { false } }
    }
}

extension ConversationCommand: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, items, streaming, waitingText, scrollToEnd, text
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .reset(items, streaming, waitingText, scrollToEnd):
            try container.encode("reset", forKey: .type)
            try container.encode(items, forKey: .items)
            // nil を省かず null として送る（JavaScript 側は null だけを受け付ける）
            try container.encode(streaming, forKey: .streaming)
            try container.encode(waitingText, forKey: .waitingText)
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
