//
//  AttemptResult.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

// answeredAt は画面で使わないため宣言しない
public struct AttemptResult: Decodable, Equatable, Sendable {
    public let questionId: String
    public let selectedChoiceId: String
    public let correctChoiceId: String
    public let isCorrect: Bool
    public let explanation: String

    public init(questionId: String, selectedChoiceId: String, correctChoiceId: String, isCorrect: Bool, explanation: String) {
        self.questionId = questionId
        self.selectedChoiceId = selectedChoiceId
        self.correctChoiceId = correctChoiceId
        self.isCorrect = isCorrect
        self.explanation = explanation
    }
}
