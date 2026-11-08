//
//  QuizPageTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import Foundation
@testable import MarkdownWebView
import Testing

private let explanation = QuizExplanationContent(heading: "解説", markdown: "解説 $x$", relatedSteps: "関連ステップ：はじめに")

private func question(_ id: String = "q1", mark: QuizChoiceMark = .normal, explanation: QuizExplanationContent? = nil) -> QuizContent {
    .question(QuizQuestionContent(
        questionID: id,
        stem: "問題文",
        choices: [QuizChoiceContent(id: "a", label: "A", markdown: "選択肢", mark: mark, badge: nil)],
        explanation: explanation
    ))
}

struct QuizPageTests {
    @Test func commands_初回は先頭を表示する() {
        #expect(QuizPage.commands(from: nil, to: question()) == [.render(question(), scroll: .top)])
    }

    @Test func commands_問題が変わると先頭を表示する() {
        let old = question("q1", mark: .correct, explanation: explanation)
        #expect(QuizPage.commands(from: old, to: question("q2")) == [.render(question("q2"), scroll: .top)])
    }

    @Test func commands_結果に変わると先頭を表示する() {
        let result = QuizContent.result(wrongStems: ["問題文"])
        #expect(QuizPage.commands(from: question(explanation: explanation), to: result) == [.render(result, scroll: .top)])
    }

    @Test func commands_回答すると解説を表示する() {
        let answered = question(mark: .correct, explanation: explanation)
        #expect(QuizPage.commands(from: question(mark: .selected), to: answered) == [.render(answered, scroll: .explanation)])
    }

    @Test func commands_選択だけ変わると位置を変えない() {
        let selected = question(mark: .selected)
        #expect(QuizPage.commands(from: question(), to: selected) == [.render(selected, scroll: .keep)])
    }

    @Test func commands_内容が同じなら何も送らない() {
        #expect(QuizPage.commands(from: question(), to: question()).isEmpty)
    }

    @Test func encode_JavaScriptが読む形にする() throws {
        let commands: [QuizCommand] = [
            .render(.question(QuizQuestionContent(
                questionID: "q1",
                stem: "問題文",
                choices: [
                    QuizChoiceContent(id: "a", label: "A", markdown: "正しい", mark: .correct, badge: "正解"),
                    QuizChoiceContent(id: "b", label: "B", markdown: "誤り", mark: .normal, badge: nil),
                ],
                explanation: explanation
            )), scroll: .explanation),
            .render(.question(QuizQuestionContent(questionID: "q2", stem: "次", choices: [], explanation: nil)), scroll: .top),
            .render(.result(wrongStems: ["問題文"]), scroll: .keep),
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(commands), as: UTF8.self)
        #expect(json == """
        [{"content":{"choices":[{"badge":"正解","id":"a","label":"A","mark":"correct","markdown":"正しい"},\
        {"badge":null,"id":"b","label":"B","mark":"normal","markdown":"誤り"}],\
        "explanation":{"heading":"解説","markdown":"解説 $x$","relatedSteps":"関連ステップ：はじめに"},\
        "kind":"question","questionId":"q1","stem":"問題文"},"scroll":"explanation","type":"render"},\
        {"content":{"choices":[],"explanation":null,"kind":"question","questionId":"q2","stem":"次"},"scroll":"top","type":"render"},\
        {"content":{"kind":"result","wrongStems":["問題文"]},"scroll":"keep","type":"render"}]
        """)
    }
}

struct QuizMessageTests {
    @Test func init_JavaScriptからの知らせを読み取る() throws {
        func decode(_ json: String) throws -> QuizMessage {
            try JSONDecoder().decode(QuizMessage.self, from: Data(json.utf8))
        }
        #expect(try decode(#"{"type":"choiceTapped","id":"a"}"#) == .choiceTapped("a"))
        #expect(try decode(#"{"type":"linkTapped","url":"https://example.com/"}"#) == .linkTapped("https://example.com/"))
        #expect(throws: DecodingError.self) { try decode(#"{"type":"unknown"}"#) }
    }
}
