//
//  ConversationPage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

enum ConversationPage: PageDefinition {
    typealias Message = ConversationMessage

    static let name = "conversation"

    static func commands(from delivered: ConversationContent?, to content: ConversationContent) -> [ConversationCommand] {
        ConversationCommand.commands(from: delivered, to: content)
    }
}
