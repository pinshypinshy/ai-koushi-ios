//
//  AttemptSummary.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

// answeredAt は画面で使わないため宣言しない
public struct AttemptSummary: Decodable, Equatable, Sendable {
    public let questionId: String
    public let isCorrect: Bool

    public init(questionId: String, isCorrect: Bool) {
        self.questionId = questionId
        self.isCorrect = isCorrect
    }
}
