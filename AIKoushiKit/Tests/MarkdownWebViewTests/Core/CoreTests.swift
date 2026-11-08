//
//  CoreTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import Foundation
@testable import MarkdownWebView
import Testing

struct IncomingMessageTests {
    private func decode(_ json: String) throws -> IncomingMessage<ConversationMessage> {
        try IncomingMessage(json: Data(json.utf8))
    }

    @Test func init_共通の知らせを読み取る() throws {
        #expect(try decode(#"{"type":"ready"}"#) == .common(.ready))
        #expect(try decode(#"{"type":"scrollBoxTouched","canScrollBack":true}"#) == .common(.scrollBoxTouched(canScrollBack: true)))
        #expect(try decode(#"{"type":"error","kind":"math","message":"m"}"#) == .common(.error(kind: .math, message: "m")))
    }

    @Test func init_ページ固有の知らせをページの型で読み取る() throws {
        #expect(try decode(#"{"type":"linkTapped","url":"https://example.com/"}"#) == .page(.linkTapped("https://example.com/")))
    }

    @Test func init_知らない種類はエラーにする() {
        #expect(throws: DecodingError.self) { try decode(#"{"type":"unknown"}"#) }
        #expect(throws: DecodingError.self) { try decode(#"{"type":"error","kind":"unknown","message":"m"}"#) }
    }
}

struct OutgoingCommandTests {
    @Test func encode_configureとページの命令を並べる() throws {
        let theme = Theme(
            colors: .init(
                text: "t", secondaryText: "s", link: "l", error: "e", border: "b",
                userMessageBackground: "ub", userMessageText: "ut", codeBackground: "cb",
                codeBlockBackground: "cbb", codeBlockText: "cbt", tableHeaderBackground: "th"
            ),
            fontSize: 17
        )
        let commands: [OutgoingCommand<ConversationCommand>] = [.configure(theme), .page(.setStreaming(nil))]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(commands), as: UTF8.self)
        #expect(json == """
        [{"theme":{"colors":{"border":"b","codeBackground":"cb","codeBlockBackground":"cbb","codeBlockText":"cbt",\
        "error":"e","link":"l","secondaryText":"s","tableHeaderBackground":"th","text":"t",\
        "userMessageBackground":"ub","userMessageText":"ut"},"fontSize":17},"type":"configure"},\
        {"text":null,"type":"setStreaming"}]
        """)
    }
}

struct BrowserURLTests {
    @Test(arguments: [
        ("https://example.com/a", true),
        ("HTTP://example.com", true),
        ("mailto:a@example.com", false),
        ("javascript:alert(1)", false),
        ("file:///index.html", false),
    ])
    func url_httpとhttpsだけを開く(string: String, opens: Bool) {
        #expect((BrowserURL.url(string) != nil) == opens)
    }
}
