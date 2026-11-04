//
//  LectureStreamLine.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/02.
//

public enum LectureStreamLine: Decodable, Equatable, Sendable {
    case delta(String)
    case done(ApiMessage)
    case error(message: String)

    private enum CodingKeys: String, CodingKey {
        case delta
        case done
        case error
    }

    // partialSaved は宣言しない。失敗の後は保存の有無によらず講義を読み直すため（§4.9）
    private struct ErrorPayload: Decodable {
        let message: String
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try container.decodeIfPresent(String.self, forKey: .delta) {
            self = .delta(text)
        } else if let message = try container.decodeIfPresent(ApiMessage.self, forKey: .done) {
            self = .done(message)
        } else if let payload = try container.decodeIfPresent(ErrorPayload.self, forKey: .error) {
            self = .error(message: payload.message)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "delta・done・error のどのキーも無い")
            )
        }
    }
}
