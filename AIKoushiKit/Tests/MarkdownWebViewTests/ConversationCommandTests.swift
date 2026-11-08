//
//  ConversationCommandTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

@testable import MarkdownWebView
import Foundation
import Testing

struct ConversationCommandTests {
    private let divider = ConversationItem.divider(id: "d1", label: "ステップ 1・はじめに")
    private let answer = ConversationItem.assistant(id: "a1", markdown: "本文 $x$")
    private let question = ConversationItem.user(id: "u1", text: "質問")

    @Test func commands_最初は全体を描いて末尾を表示する() {
        let content = ConversationContent(id: "c1", items: [divider, answer], streaming: nil)
        #expect(ConversationCommand.commands(from: nil, to: content) == [
            .reset(items: [divider, answer], streaming: nil, scrollToEnd: true),
        ])
    }

    @Test func commands_講義が変わると全体を描いて末尾を表示する() {
        let old = ConversationContent(id: "c1", items: [divider, answer], streaming: nil)
        let new = ConversationContent(id: "c2", items: [divider], streaming: "")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider], streaming: "", scrollToEnd: true),
        ])
    }

    @Test func commands_内容が同じなら何も送らない() {
        let content = ConversationContent(id: "c1", items: [divider, answer], streaming: "途中")
        #expect(ConversationCommand.commands(from: content, to: content).isEmpty)
    }

    @Test func commands_受信中の文字を更新する() {
        let old = ConversationContent(id: "c1", items: [divider], streaming: "")
        let new = ConversationContent(id: "c1", items: [divider], streaming: "本文")
        #expect(ConversationCommand.commands(from: old, to: new) == [.setStreaming("本文")])
    }

    @Test func commands_確定した回答を足して受信中の表示を消す() {
        let old = ConversationContent(id: "c1", items: [divider], streaming: "本文 $x$")
        let new = ConversationContent(id: "c1", items: [divider, answer], streaming: nil)
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .append(items: [answer], scrollToEnd: false),
            .setStreaming(nil),
        ])
    }

    @Test func commands_質問を送ると末尾を表示する() {
        let old = ConversationContent(id: "c1", items: [divider, answer], streaming: nil)
        let new = ConversationContent(id: "c1", items: [divider, answer, question], streaming: "")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .append(items: [question], scrollToEnd: true),
            .setStreaming(""),
        ])
    }

    /// 講義を取り直して、発言が置き換わったとき（§4.9）
    @Test func commands_発言が置き換わると全体を描くが移動しない() {
        let old = ConversationContent(id: "c1", items: [divider, question], streaming: nil)
        let saved = ConversationItem.user(id: "u-server", text: "質問")
        let new = ConversationContent(id: "c1", items: [divider, saved], streaming: nil)
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider, saved], streaming: nil, scrollToEnd: false),
        ])
    }

    /// 回答の無い質問の注記が消えると同時に、次の発言を送ったとき（§3.2）
    @Test func commands_全体を描くときも質問を送ると末尾を表示する() {
        let notice = ConversationItem.notice(id: "n1", text: "応答を取得できませんでした")
        let next = ConversationItem.user(id: "u2", text: "次の質問")
        let old = ConversationContent(id: "c1", items: [divider, question, notice], streaming: nil)
        let new = ConversationContent(id: "c1", items: [divider, question, next], streaming: "")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider, question, next], streaming: "", scrollToEnd: true),
        ])
    }

    @Test func encode_JavaScriptが読む形にする() throws {
        let notice = ConversationItem.notice(id: "n1", text: "注記")
        let commands: [ConversationCommand] = [
            .reset(items: [divider, answer, question, notice], streaming: nil, scrollToEnd: true),
            .append(items: [], scrollToEnd: false),
            .setStreaming("途中"),
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = String(decoding: try encoder.encode(commands), as: UTF8.self)
        #expect(json == """
        [{"items":[{"id":"d1","label":"ステップ 1・はじめに","type":"divider"},\
        {"id":"a1","markdown":"本文 $x$","type":"assistant"},\
        {"id":"u1","text":"質問","type":"user"},\
        {"id":"n1","text":"注記","type":"notice"}],"scrollToEnd":true,"streaming":null,"type":"reset"},\
        {"items":[],"scrollToEnd":false,"type":"append"},\
        {"text":"途中","type":"setStreaming"}]
        """)
    }
}

struct WebMessageTests {
    @Test(arguments: [
        ("https://example.com/a", true),
        ("HTTP://example.com", true),
        ("mailto:a@example.com", false),
        ("javascript:alert(1)", false),
        ("file:///index.html", false),
    ])
    func browserURL_httpとhttpsだけを開く(string: String, opens: Bool) {
        #expect((WebMessage.browserURL(string) != nil) == opens)
    }

    @Test func init_JavaScriptからのメッセージを読み取る() throws {
        func decode(_ json: String) throws -> WebMessage {
            try JSONDecoder().decode(WebMessage.self, from: Data(json.utf8))
        }
        #expect(try decode(#"{"type":"ready"}"#) == .ready)
        #expect(try decode(#"{"type":"linkTapped","url":"https://example.com/"}"#) == .linkTapped("https://example.com/"))
        #expect(try decode(#"{"type":"scrollBoxTouched","canScrollBack":true}"#) == .scrollBoxTouched(canScrollBack: true))
        #expect(try decode(#"{"type":"error","kind":"math","message":"m"}"#) == .error(kind: .math, message: "m"))
        #expect(throws: DecodingError.self) { try decode(#"{"type":"unknown"}"#) }
    }
}
