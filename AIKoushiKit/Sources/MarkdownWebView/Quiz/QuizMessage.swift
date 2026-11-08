//
//  QuizMessage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

/// 確認テストのページから届く知らせ。JSON の形は WebRenderer/src/quiz/commands.ts の QuizMessage と対になる
enum QuizMessage: Equatable, Decodable {
    case choiceTapped(String)
    case linkTapped(String)

    private enum CodingKeys: String, CodingKey {
        case type, id, url
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "choiceTapped":
            self = .choiceTapped(try container.decode(String.self, forKey: .id))
        case "linkTapped":
            self = .linkTapped(try container.decode(String.self, forKey: .url))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "知らない種類：\(type)")
        }
    }
}
