//
//  CommonMessage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import Foundation

/// どのページからも届く知らせ。JSON の形は WebRenderer/src/core/bridge.ts の CommonMessage と対になる
enum CommonMessage: Equatable, Decodable {
    case ready
    case scrollBoxTouched(canScrollBack: Bool)
    case error(kind: ErrorKind, message: String)

    enum ErrorKind: String, Equatable, Decodable {
        case script
        case command
        case math
    }

    static let types: Set<String> = ["ready", "scrollBoxTouched", "error"]

    private enum CodingKeys: String, CodingKey {
        case type, canScrollBack, kind, message
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "ready":
            self = .ready
        case "scrollBoxTouched":
            self = .scrollBoxTouched(canScrollBack: try container.decode(Bool.self, forKey: .canScrollBack))
        case "error":
            self = .error(
                kind: try container.decode(ErrorKind.self, forKey: .kind),
                message: try container.decode(String.self, forKey: .message)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "知らない種類：\(type)")
        }
    }
}

/// 届いた知らせを、共通の知らせとページ固有の知らせに振り分ける
enum IncomingMessage<PageMessage: Decodable & Equatable>: Equatable {
    case common(CommonMessage)
    case page(PageMessage)

    private struct TypeOnly: Decodable {
        let type: String
    }

    /// ページ固有の知らせの型が知らない種類なら、DecodingError を投げる
    init(json data: Data) throws {
        let decoder = JSONDecoder()
        let type = try decoder.decode(TypeOnly.self, from: data).type
        if CommonMessage.types.contains(type) {
            self = .common(try decoder.decode(CommonMessage.self, from: data))
        } else {
            self = .page(try decoder.decode(PageMessage.self, from: data))
        }
    }
}
