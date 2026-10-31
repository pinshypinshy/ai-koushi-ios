//
//  ConversationRenderingTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

@testable import ConversationWebView
import Foundation
import SwiftUI
import Testing
import WebKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ConversationRenderingTests {
    @Test func rendersEveryFormulaInMaterial() async throws {
        let harness = RenderingHarness()
        let material = try #require(Bundle.module.url(forResource: "material-visual-computing", withExtension: "md"))
        let markdown = try String(contentsOf: material, encoding: .utf8)

        harness.show(ConversationContent(id: "c1", items: [.assistant(id: "material", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"material\"]') !== null")

        // 教材に含まれる数式の数
        #expect(try await harness.evaluate("document.querySelectorAll('[data-id=\"material\"] .katex').length") == "263")
        #expect(harness.errors.isEmpty)
        // 幅 375pt で画面幅を超える数式の数
        #expect(try await harness.evaluate("document.querySelectorAll('.math-scroll').length") == "3")
        #expect(try await harness.evaluate("document.scrollingElement.scrollWidth <= innerWidth") == "true")
    }

    @Test func loadsBundledStylesAndFonts() async throws {
        let harness = RenderingHarness()
        harness.show(ConversationContent(id: "c1", items: [.assistant(id: "a1", markdown: "$x^2$")], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"a1\"] .katex') !== null")

        #expect(try await harness.evaluate("getComputedStyle(document.body).overflowX") == "\"hidden\"")
        try await harness.waitUntil("[...document.fonts].some(f => f.family.includes('KaTeX_Main') && f.status === 'loaded')")
    }

    @Test func reportsFormulaKaTeXCannotParse() async throws {
        let harness = RenderingHarness()
        harness.show(ConversationContent(id: "c1", items: [.assistant(id: "a1", markdown: "$\\undefinedcommand{x}$")], streaming: nil))
        try await harness.waitUntil { harness.errors.contains { $0.kind == .math } }
    }

    @Test func reportsCommandOfWrongShape() async throws {
        let harness = RenderingHarness()
        harness.show(ConversationContent(id: "c1", items: [.divider(id: "d1", label: "ステップ 1")], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"d1\"]') !== null")

        _ = try await harness.webView.callAsyncJavaScript(
            "conversation.apply(json)",
            arguments: ["json": #"[{"type":"append","items":[{"type":"assistant","id":"x"}],"scrollToEnd":false}]"#],
            contentWorld: .page
        )
        try await harness.waitUntil { harness.errors.contains { $0.kind == .command } }
    }

    @Test func showsRawHTMLAsTextAndImagesAsAltText() async throws {
        let harness = RenderingHarness()
        let markdown = "<b>太字</b> <script>window.injected = true</script>\n\n![猫の写真](https://example.com/cat.png)"
        harness.show(ConversationContent(id: "c1", items: [.assistant(id: "a1", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelector('[data-id=\"a1\"]') !== null")

        #expect(try await harness.evaluate("document.querySelectorAll('[data-id=\"a1\"] b, [data-id=\"a1\"] script, img').length") == "0")
        #expect(try await harness.evaluate("window.injected === undefined") == "true")
        let text = try await harness.evaluate("document.querySelector('[data-id=\"a1\"]').textContent")
        #expect(text.contains("<b>太字</b>"))
        #expect(text.contains("猫の写真"))
    }

    @Test func showsStreamingAnswerUntilItIsFinished() async throws {
        let harness = RenderingHarness()
        let divider = ConversationItem.divider(id: "d1", label: "ステップ 1・はじめに")

        harness.show(ConversationContent(id: "c1", items: [divider], streaming: ""))
        try await harness.waitUntil("document.querySelector('.streaming')?.textContent === '応答を待っています'")

        harness.show(ConversationContent(id: "c1", items: [divider], streaming: "途中の **本文**"))
        try await harness.waitUntil("document.querySelector('.streaming strong')?.textContent === '本文'")

        harness.show(ConversationContent(id: "c1", items: [divider, .assistant(id: "a1", markdown: "途中の **本文**")], streaming: nil))
        try await harness.waitUntil("document.querySelector('.streaming') === null && document.querySelector('[data-id=\"a1\"]') !== null")
        #expect(try await harness.evaluate("[...document.getElementById('conversation').children].map(e => e.dataset.id)") == #"["d1","a1"]"#)
    }

    @Test func passesOnlyBrowserLinksToSwift() async throws {
        let harness = RenderingHarness()
        var opened: [URL] = []
        harness.coordinator.onLinkTap = { opened.append($0) }
        let markdown = "[メール](mailto:a@example.com) と [リンク](https://example.com/page)"
        harness.show(ConversationContent(id: "c1", items: [.assistant(id: "a1", markdown: markdown)], streaming: nil))
        try await harness.waitUntil("document.querySelectorAll('[data-id=\"a1\"] a').length === 2")

        _ = try await harness.evaluate("(document.querySelectorAll('[data-id=\"a1\"] a').forEach(a => a.click()), true)")
        try await harness.waitUntil { !opened.isEmpty }
        try await Task.sleep(for: .milliseconds(200))
        #expect(opened == [URL(string: "https://example.com/page")])
    }
}

@MainActor
final class RenderingHarness {
    let coordinator = ConversationCoordinator()
    let webView: WKWebView
    private(set) var errors: [(kind: WebMessage.ErrorKind, message: String)] = []

    init() {
        webView = coordinator.makeWebView()
        webView.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        coordinator.onError = { [weak self] kind, message in
            self?.errors.append((kind, message))
        }
    }

    func show(_ content: ConversationContent) {
        coordinator.update(content: content, configuration: ConversationConfiguration(environment: EnvironmentValues()))
    }

    /// 式の値を JSON の文字列で返す
    func evaluate(_ expression: String) async throws -> String {
        let result = try await webView.callAsyncJavaScript(
            "return JSON.stringify(\(expression))",
            arguments: [:],
            contentWorld: .page
        )
        return try #require(result as? String)
    }

    func waitUntil(_ condition: String, timeout: Duration = .seconds(10)) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if try await evaluate("Boolean(\(condition))") == "true" { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("待っている条件が満たされなかった：\(condition)")
        throw CancellationError()
    }

    func waitUntil(timeout: Duration = .seconds(10), _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("待っている条件が満たされなかった")
        throw CancellationError()
    }
}
