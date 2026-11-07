//
//  QuizResponse.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

public struct QuizResponse: Decodable, Equatable, Sendable {
    public let questions: [ApiQuestion]
    public let latestAttempts: [AttemptSummary]

    public init(questions: [ApiQuestion], latestAttempts: [AttemptSummary]) {
        self.questions = questions
        self.latestAttempts = latestAttempts
    }
}
