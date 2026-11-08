//
//  QuizPage.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

/// 文字が少しずつ届くことは無いので、差分ではなく毎回全体を送る
enum QuizPage: PageDefinition {
    typealias Message = QuizMessage

    static let name = "quiz"

    static func commands(from delivered: QuizContent?, to content: QuizContent) -> [QuizCommand] {
        guard delivered != content else { return [] }
        return [.render(content, scroll: scroll(from: delivered, to: content))]
    }

    private static func scroll(from delivered: QuizContent?, to content: QuizContent) -> QuizScroll {
        guard case let .question(old)? = delivered, case let .question(new) = content, old.questionID == new.questionID else {
            // 新しい問題は先頭から読ませる（§4.16）
            return .top
        }
        // 回答したら、画面の外にあるかもしれない解説を見せる（§3.7）
        if old.explanation == nil, new.explanation != nil { return .explanation }
        return .keep
    }
}
