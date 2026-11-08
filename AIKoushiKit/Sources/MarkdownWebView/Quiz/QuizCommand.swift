//
//  QuizCommand.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

/// JSON の形は WebRenderer/src/quiz/commands.ts の QuizCommand と対になる
enum QuizCommand: Equatable {
    case render(QuizContent, scroll: QuizScroll)
}

enum QuizScroll: String, Equatable, Encodable {
    case top
    case explanation
    case keep
}

extension QuizCommand: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, content, scroll
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .render(content, scroll):
            try container.encode("render", forKey: .type)
            try container.encode(content, forKey: .content)
            try container.encode(scroll, forKey: .scroll)
        }
    }
}
