//
//  QuizRenderingTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import Foundation
@testable import MarkdownWebView
import Testing

// WebView を同時に立ち上げると、どれも読み込みが待ち時間に間に合わなくなるため1つずつ実行する
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct QuizRenderingTests {
    @Test func 問題文と選択肢と解説の数式をすべて描画する() async throws {
        let harness = RenderingHarness<QuizPage>()
        harness.show(question(
            stem: "行列 $A$ の行列式は？\n\n$$\n\\det A = ad - bc\n$$",
            choices: [choice("a", "$-2$"), choice("b", "$\\frac{1}{2}$")],
            explanation: QuizExplanationContent(heading: "解説", markdown: "$\\det A = -2$", relatedSteps: "関連ステップ：行列")
        ))
        try await harness.waitUntil("document.querySelector('.explanation') !== null")

        #expect(try await harness.evaluate("document.querySelectorAll('.katex').length") == "5")
        #expect(harness.errors.isEmpty)
        #expect(try await harness.evaluate("document.scrollingElement.scrollWidth <= innerWidth") == "true")
    }

    @Test func 選択肢に触れると選んだIDをSwiftへ知らせる() async throws {
        let harness = RenderingHarness<QuizPage>()
        var received: [QuizMessage] = []
        harness.coordinator.onMessage = { received.append($0) }
        harness.show(question(choices: [choice("a", "選択肢A"), choice("b", "選択肢 $x$")]))
        try await harness.waitUntil("document.querySelector('[data-choice-id=\"b\"]') !== null")

        _ = try await harness.evaluate("(document.querySelector('[data-choice-id=\"b\"] .katex').click(), true)")
        try await harness.waitUntil { !received.isEmpty }
        #expect(received == [.choiceTapped("b")])
    }

    @Test func 選択肢の中のリンクは選択として知らせない() async throws {
        let harness = RenderingHarness<QuizPage>()
        var received: [QuizMessage] = []
        harness.coordinator.onMessage = { received.append($0) }
        harness.show(question(choices: [choice("a", "[参考](https://example.com/page)")]))
        try await harness.waitUntil("document.querySelector('[data-choice-id=\"a\"] a') !== null")

        _ = try await harness.evaluate("(document.querySelector('[data-choice-id=\"a\"] a').click(), true)")
        try await harness.waitUntil { !received.isEmpty }
        try await Task.sleep(for: .milliseconds(200))
        #expect(received == [.linkTapped("https://example.com/page")])
    }

    @Test func 回答後は正解とあなたの回答の印を付ける() async throws {
        let harness = RenderingHarness<QuizPage>()
        harness.show(question(
            choices: [
                QuizChoiceContent(id: "a", label: "A", markdown: "正しい", mark: .correct, badge: "正解"),
                QuizChoiceContent(id: "b", label: "B", markdown: "選んだ", mark: .yourAnswer, badge: "あなたの回答"),
                QuizChoiceContent(id: "c", label: "C", markdown: "ほか", mark: .normal, badge: nil),
            ],
            explanation: QuizExplanationContent(heading: "解説", markdown: "本文", relatedSteps: "関連ステップ：はじめに")
        ))
        try await harness.waitUntil("document.querySelector('.explanation') !== null")

        #expect(try await harness.evaluate("[...document.querySelectorAll('.choice')].map(c => c.className)")
            == #"["choice correct","choice yourAnswer","choice normal"]"#)
        #expect(try await harness.evaluate("[...document.querySelectorAll('.choice-badge')].map(b => b.textContent)")
            == #"["正解","あなたの回答"]"#)
        #expect(try await harness.evaluate("[...document.querySelectorAll('.choice')].every(c => c.getAttribute('aria-disabled') === 'true')")
            == "true")
        #expect(try await harness.evaluate("document.querySelector('.explanation-heading').textContent") == #""解説""#)
        #expect(try await harness.evaluate("document.querySelector('.related').textContent") == #""関連ステップ：はじめに""#)
    }

    @Test func 選択肢の高さを44px以上にする() async throws {
        let harness = RenderingHarness<QuizPage>()
        harness.show(question(choices: [choice("a", "短"), choice("b", "B")]))
        try await harness.waitUntil("document.querySelectorAll('.choice').length === 2")

        #expect(try await harness.evaluate("[...document.querySelectorAll('.choice')].every(c => c.getBoundingClientRect().height >= 44)")
            == "true")
    }

    @Test func 誤答の一覧の数式を描画する() async throws {
        let harness = RenderingHarness<QuizPage>()
        harness.show(.result(wrongStems: ["$x^2$ の微分は？", "$\\int_0^1 x\\,dx$ の値は？"]))
        try await harness.waitUntil("document.querySelectorAll('.wrong-stem').length === 2")

        #expect(try await harness.evaluate("document.querySelectorAll('.wrong-stem .katex').length") == "2")
        #expect(harness.errors.isEmpty)
    }

    @Test func 回答すると解説の先頭へ移動する() async throws {
        let harness = RenderingHarness<QuizPage>()
        let longStem = (1...30).map { "問題文の段落 \($0)" }.joined(separator: "\n\n")
        let longExplanation = (1...30).map { "解説の段落 \($0)" }.joined(separator: "\n\n")
        harness.show(question(stem: longStem, choices: [choice("a", "選択肢")]))
        try await harness.waitUntil("document.querySelector('.choice') !== null")
        #expect(try await harness.evaluate("document.scrollingElement.scrollTop") == "0")

        harness.show(question(
            stem: longStem,
            choices: [QuizChoiceContent(id: "a", label: "A", markdown: "選択肢", mark: .correct, badge: "正解")],
            explanation: QuizExplanationContent(heading: "解説", markdown: longExplanation, relatedSteps: "関連ステップ：はじめに")
        ))
        try await harness.waitUntil("document.querySelector('.explanation') !== null")
        #expect(try await harness.evaluate("Math.abs(document.querySelector('.explanation').getBoundingClientRect().top) < 1") == "true")
    }
}

private func question(
    stem: String = "問題文",
    choices: [QuizChoiceContent],
    explanation: QuizExplanationContent? = nil
) -> QuizContent {
    .question(QuizQuestionContent(questionID: "q1", stem: stem, choices: choices, explanation: explanation))
}

private func choice(_ id: String, _ markdown: String) -> QuizChoiceContent {
    QuizChoiceContent(id: id, label: id.uppercased(), markdown: markdown, mark: .normal, badge: nil)
}
