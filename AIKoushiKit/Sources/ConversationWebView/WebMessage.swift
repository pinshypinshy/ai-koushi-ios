//
//  WebMessage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import Foundation

/// JSON の形は WebRenderer/src/bridge.ts の WebMessage と対になる
enum WebMessage: Equatable, Decodable {
    case ready
    case linkTapped(String)
    case error(kind: ErrorKind, message: String)

    enum ErrorKind: String, Equatable, Decodable {
        case script
        case command
        case math
    }

    private enum CodingKeys: String, CodingKey {
        case type, url, kind, message
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "ready":
            self = .ready
        case "linkTapped":
            self = .linkTapped(try container.decode(String.self, forKey: .url))
        case "error":
            self = .error(
                kind: try container.decode(ErrorKind.self, forKey: .kind),
                message: try container.decode(String.self, forKey: .message)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "知らない種類：\(type)")
        }
    }

    static func browserURL(_ string: String) -> URL? {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
