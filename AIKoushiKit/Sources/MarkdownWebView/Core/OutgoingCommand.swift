//
//  OutgoingCommand.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

/// JavaScript へ送る命令。configure は WebRenderer/src/core/page.ts が受け、ほかはページに渡る
enum OutgoingCommand<PageCommand: Encodable & Equatable>: Equatable, Encodable {
    case configure(Theme)
    case page(PageCommand)

    private enum CodingKeys: String, CodingKey {
        case type, theme
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .configure(theme):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("configure", forKey: .type)
            try container.encode(theme, forKey: .theme)
        case let .page(command):
            try command.encode(to: encoder)
        }
    }
}
