//
//  ConversationRenderingTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

@testable import MarkdownWebView
import Foundation
import Testing
import WebKit

// WebView を同時に立ち上げると、どれも読み込みが待ち時間に間に合わなくなるため1つずつ実行する
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct ConversationRenderingTests {
    @Test func 教材の数式をすべて描画する() async throws {
        let harness = RenderingHarness<ConversationPage>()
        let material = try #require(Bundle.module.url(forResource: "formulas", withExtension: "md"))
        let markdown = try String(contentsOf: material, encoding: .utf8)

        harness.show(conversation([.assistant(id: "material", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"material\"]') !== null")

        // 教材に含まれる数式の数
        #expect(try await harness.evaluate("document.querySelectorAll('[data-id=\"material\"] .katex').length") == "263")
        #expect(harness.errors.isEmpty)
        #expect(try await harness.evaluate("document.scrollingElement.scrollWidth <= innerWidth") == "true")
    }

    /// 改行できない幅の文中の数式だけを、横にスクロールする枠に入れる（§3.2）
    @Test func 幅を超える文中の数式だけを枠に入れる() async throws {
        let harness = RenderingHarness<ConversationPage>()
        let entries = (1...30).map { "a_{\($0)}" }.joined(separator: " & ")
        let markdown = "短い数式 $x^2$\n\n$\\begin{pmatrix} \(entries) \\end{pmatrix}$"
        harness.show(conversation([.assistant(id: "a1", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"a1\"] .katex') !== null")

        #expect(try await harness.evaluate("document.querySelectorAll('.katex').length") == "2")
        #expect(try await harness.evaluate("document.querySelectorAll('.math-scroll').length") == "1")
        #expect(try await harness.evaluate("document.scrollingElement.scrollWidth <= innerWidth") == "true")
    }

    @Test func 同梱のスタイルとフォントを読み込む() async throws {
        let harness = RenderingHarness<ConversationPage>()
        harness.show(conversation([.assistant(id: "a1", markdown: "$x^2$")], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"a1\"] .katex') !== null")

        #expect(try await harness.evaluate("getComputedStyle(document.body).overflowX") == "\"hidden\"")
        try await harness.waitUntil("[...document.fonts].some(f => f.family.includes('KaTeX_Main') && f.status === 'loaded')")
    }

    @Test func KaTeXが読めない数式を報告する() async throws {
        let harness = RenderingHarness<ConversationPage>()
        harness.show(conversation([.assistant(id: "a1", markdown: "$\\undefinedcommand{x}$")], streaming: nil))
        try await harness.waitUntil { harness.errors.contains { $0.kind == .math } }
    }

    @Test func 形の違う命令を報告する() async throws {
        let harness = RenderingHarness<ConversationPage>()
        harness.show(conversation([.divider(id: "d1", label: "ステップ 1")], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"d1\"]') !== null")

        _ = try await harness.webView.callAsyncJavaScript(
            "page.apply(json)",
            arguments: ["json": #"[{"type":"append","items":[{"type":"assistant","id":"x"}],"scrollToEnd":false}]"#],
            contentWorld: .page
        )
        try await harness.waitUntil { harness.errors.contains { $0.kind == .command } }
    }

    @Test func 生のHTMLは文字のまま表示し画像は説明を表示する() async throws {
        let harness = RenderingHarness<ConversationPage>()
        let markdown = "<b>太字</b> <script>window.injected = true</script>\n\n![猫の写真](https://example.com/cat.png)"
        harness.show(conversation([.assistant(id: "a1", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"a1\"]') !== null")

        #expect(try await harness.evaluate("document.querySelectorAll('[data-id=\"a1\"] b, [data-id=\"a1\"] script, img').length") == "0")
        #expect(try await harness.evaluate("window.injected === undefined") == "true")
        let text = try await harness.evaluate("document.querySelector('[data-id=\"a1\"]').textContent")
        #expect(text.contains("<b>太字</b>"))
        #expect(text.contains("猫の写真"))
    }

    @Test func 受信中の発言を確定するまで表示する() async throws {
        let harness = RenderingHarness<ConversationPage>()
        let divider = ConversationItem.divider(id: "d1", label: "ステップ 1・はじめに")

        harness.show(conversation([divider], streaming: ""))
        try await harness.waitUntil("document.querySelector('.streaming')?.textContent === '応答を待っています'")

        harness.show(conversation([divider], streaming: "途中の **本文**"))
        try await harness.waitUntil("document.querySelector('.streaming strong')?.textContent === '本文'")

        harness.show(conversation([divider, .assistant(id: "a1", markdown: "途中の **本文**")], streaming: nil))
        try await harness.waitUntil("document.querySelector('.streaming') === null && document.querySelector('[data-id=\"a1\"]') !== null")
        #expect(try await harness.evaluate("[...document.getElementById('page').children].map(e => e.dataset.id)") == #"["d1","a1"]"#)
    }

    @Test func 注記をMarkdownとして解釈せず文字のまま表示する() async throws {
        let harness = RenderingHarness<ConversationPage>()
        harness.show(conversation([.notice(id: "n1", text: "**途切れました**")], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"n1\"]') !== null")

        #expect(try await harness.evaluate("document.querySelector('[data-id=\"n1\"]').className") == #""notice""#)
        #expect(try await harness.evaluate("document.querySelector('[data-id=\"n1\"]').textContent") == #""**途切れました**""#)
        #expect(harness.errors.isEmpty)
    }

    @Test func 枠をまだ右へ戻せるときだけSwiftへ知らせる() async throws {
        let harness = RenderingHarness<ConversationPage>()
        var received: [Bool] = []
        harness.coordinator.onScrollBoxTouch = { received.append($0) }
        let entries = (1...30).map { "a_{\($0)}" }.joined(separator: " & ")
        let markdown = "本文\n\n$$\n\\begin{pmatrix} \(entries) \\end{pmatrix}\n$$"
        harness.show(conversation([.assistant(id: "a1", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelector('.katex-display') !== null")

        func dispatch(_ type: String, on selector: String) async throws -> Bool {
            received = []
            _ = try await harness.evaluate(
                "document.querySelector('\(selector)').dispatchEvent(new Event('\(type)', { bubbles: true }))"
            )
            try await harness.waitUntil { !received.isEmpty }
            return try #require(received.first)
        }

        #expect(try await dispatch("touchstart", on: ".katex-display .katex") == false)
        _ = try await harness.evaluate("document.querySelector('.katex-display').scrollLeft = 40")
        #expect(try await harness.evaluate("document.querySelector('.katex-display').scrollLeft > 0") == "true")
        #expect(try await dispatch("touchstart", on: ".katex-display .katex") == true)
        #expect(try await dispatch("touchend", on: ".katex-display .katex") == false)
        #expect(try await dispatch("touchstart", on: "[data-id=\"a1\"] p") == false)
    }

    @Test func httpとhttpsのリンクだけをSwiftへ渡す() async throws {
        let harness = RenderingHarness<ConversationPage>()
        var opened: [URL] = []
        // ConversationWebView と同じく、http と https だけを URL にする
        harness.coordinator.onMessage = { message in
            if case let .linkTapped(string) = message, let url = BrowserURL.url(string) {
                opened.append(url)
            }
        }
        let markdown = "[メール](mailto:a@example.com) と [リンク](https://example.com/page)"
        harness.show(conversation([.assistant(id: "a1", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelectorAll('[data-id=\"a1\"] a').length === 2")

        _ = try await harness.evaluate("(document.querySelectorAll('[data-id=\"a1\"] a').forEach(a => a.click()), true)")
        try await harness.waitUntil { !opened.isEmpty }
        try await Task.sleep(for: .milliseconds(200))
        #expect(opened == [URL(string: "https://example.com/page")])
    }
}

private func conversation(_ items: [ConversationItem], streaming: String?) -> ConversationContent {
    ConversationContent(id: "c1", items: items, streaming: streaming, waitingText: "応答を待っています")
}
