//
//  QuizContent.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

public enum QuizContent: Equatable, Sendable {
    case question(QuizQuestionContent)
    /// 今回のテストで間違えた問題の問題文（§3.8）
    case result(wrongStems: [String])
}

public struct QuizQuestionContent: Equatable, Sendable {
    public var questionID: String
    public var stem: String
    public var choices: [QuizChoiceContent]
    /// 回答した後だけ
    public var explanation: QuizExplanationContent?

    public init(questionID: String, stem: String, choices: [QuizChoiceContent], explanation: QuizExplanationContent?) {
        self.questionID = questionID
        self.stem = stem
        self.choices = choices
        self.explanation = explanation
    }
}

public struct QuizChoiceContent: Equatable, Sendable {
    public var id: String
    public var label: String
    public var markdown: String
    public var mark: QuizChoiceMark
    public var badge: String?

    public init(id: String, label: String, markdown: String, mark: QuizChoiceMark, badge: String?) {
        self.id = id
        self.label = label
        self.markdown = markdown
        self.mark = mark
        self.badge = badge
    }
}

public enum QuizChoiceMark: String, Equatable, Sendable {
    case normal
    case selected
    case correct
    /// 誤って選んだ選択肢
    case yourAnswer
}

public struct QuizExplanationContent: Equatable, Sendable {
    public var heading: String
    public var markdown: String
    public var relatedSteps: String

    public init(heading: String, markdown: String, relatedSteps: String) {
        self.heading = heading
        self.markdown = markdown
        self.relatedSteps = relatedSteps
    }
}

// JSON の形は WebRenderer/src/quiz/commands.ts の QuizContent と対になる
extension QuizContent: Encodable {
    private enum CodingKeys: String, CodingKey {
        case kind, questionId, stem, choices, explanation, wrongStems
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .question(question):
            try container.encode("question", forKey: .kind)
            try container.encode(question.questionID, forKey: .questionId)
            try container.encode(question.stem, forKey: .stem)
            try container.encode(question.choices, forKey: .choices)
            // nil を省かず null として送る（JavaScript 側は null だけを受け付ける）
            try container.encode(question.explanation, forKey: .explanation)
        case let .result(wrongStems):
            try container.encode("result", forKey: .kind)
            try container.encode(wrongStems, forKey: .wrongStems)
        }
    }
}

extension QuizChoiceContent: Encodable {
    private enum CodingKeys: String, CodingKey {
        case id, label, markdown, mark, badge
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(markdown, forKey: .markdown)
        try container.encode(mark.rawValue, forKey: .mark)
        try container.encode(badge, forKey: .badge)
    }
}

extension QuizExplanationContent: Encodable {}
