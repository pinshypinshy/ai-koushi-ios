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
    private let waiting = "応答を待っています"

    private func content(_ id: String, _ items: [ConversationItem], streaming: String?, waitingText: String? = nil) -> ConversationContent {
        ConversationContent(id: id, items: items, streaming: streaming, waitingText: waitingText ?? waiting)
    }

    @Test func commands_最初は全体を描いて末尾を表示する() {
        let content = content("c1", [divider, answer], streaming: nil)
        #expect(ConversationCommand.commands(from: nil, to: content) == [
            .reset(items: [divider, answer], streaming: nil, waitingText: waiting, scrollToEnd: true),
        ])
    }

    @Test func commands_講義が変わると全体を描いて末尾を表示する() {
        let old = content("c1", [divider, answer], streaming: nil)
        let new = content("c2", [divider], streaming: "")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider], streaming: "", waitingText: waiting, scrollToEnd: true),
        ])
    }

    @Test func commands_内容が同じなら何も送らない() {
        let content = content("c1", [divider, answer], streaming: "途中")
        #expect(ConversationCommand.commands(from: content, to: content).isEmpty)
    }

    @Test func commands_受信中の文字を更新する() {
        let old = content("c1", [divider], streaming: "")
        let new = content("c1", [divider], streaming: "本文")
        #expect(ConversationCommand.commands(from: old, to: new) == [.setStreaming("本文")])
    }

    @Test func commands_確定した回答を足して受信中の表示を消す() {
        let old = content("c1", [divider], streaming: "本文 $x$")
        let new = content("c1", [divider, answer], streaming: nil)
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .append(items: [answer], scrollToEnd: false),
            .setStreaming(nil),
        ])
    }

    @Test func commands_質問を送ると末尾を表示する() {
        let old = content("c1", [divider, answer], streaming: nil)
        let new = content("c1", [divider, answer, question], streaming: "")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .append(items: [question], scrollToEnd: true),
            .setStreaming(""),
        ])
    }

    /// 講義を取り直して、発言が置き換わったとき（§4.9）
    @Test func commands_発言が置き換わると全体を描くが移動しない() {
        let old = content("c1", [divider, question], streaming: nil)
        let saved = ConversationItem.user(id: "u-server", text: "質問")
        let new = content("c1", [divider, saved], streaming: nil)
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider, saved], streaming: nil, waitingText: waiting, scrollToEnd: false),
        ])
    }

    /// 回答の無い質問の注記が消えると同時に、次の発言を送ったとき（§3.2）
    @Test func commands_全体を描くときも質問を送ると末尾を表示する() {
        let notice = ConversationItem.notice(id: "n1", text: "応答を取得できませんでした")
        let next = ConversationItem.user(id: "u2", text: "次の質問")
        let old = content("c1", [divider, question, notice], streaming: nil)
        let new = content("c1", [divider, question, next], streaming: "")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider, question, next], streaming: "", waitingText: waiting, scrollToEnd: true),
        ])
    }

    @Test func commands_待ちの文字が変わると全体を描くが移動しない() {
        let old = content("c1", [divider], streaming: "")
        let new = content("c1", [divider], streaming: "", waitingText: "待っています")
        #expect(ConversationCommand.commands(from: old, to: new) == [
            .reset(items: [divider], streaming: "", waitingText: "待っています", scrollToEnd: false),
        ])
    }

    @Test func encode_JavaScriptが読む形にする() throws {
        let notice = ConversationItem.notice(id: "n1", text: "注記")
        let commands: [ConversationCommand] = [
            .reset(items: [divider, answer, question, notice], streaming: nil, waitingText: waiting, scrollToEnd: true),
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
        {"id":"n1","text":"注記","type":"notice"}],"scrollToEnd":true,"streaming":null,"type":"reset","waitingText":"応答を待っています"},\
        {"items":[],"scrollToEnd":false,"type":"append"},\
        {"text":"途中","type":"setStreaming"}]
        """)
    }
}

struct ConversationMessageTests {
    @Test func init_JavaScriptからの知らせを読み取る() throws {
        func decode(_ json: String) throws -> ConversationMessage {
            try JSONDecoder().decode(ConversationMessage.self, from: Data(json.utf8))
        }
        #expect(try decode(#"{"type":"linkTapped","url":"https://example.com/"}"#) == .linkTapped("https://example.com/"))
        #expect(throws: DecodingError.self) { try decode(#"{"type":"choiceTapped","id":"a"}"#) }
    }
}
