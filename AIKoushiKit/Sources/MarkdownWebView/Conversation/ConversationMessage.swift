//
//  ConversationMessage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

/// 会話のページから届く知らせ。JSON の形は WebRenderer/src/conversation/commands.ts の ConversationMessage と対になる
enum ConversationMessage: Equatable, Decodable {
    case linkTapped(String)

    private enum CodingKeys: String, CodingKey {
        case type, url
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "linkTapped":
            self = .linkTapped(try container.decode(String.self, forKey: .url))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "知らない種類：\(type)")
        }
    }
}
