//
//  ApiQuestion.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/07.
//

public struct ApiChoice: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let body: String

    public init(id: String, body: String) {
        self.id = id
        self.body = body
    }
}

public struct ApiQuestion: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let stem: String
    public let choices: [ApiChoice]
    public let coveredStepIds: [String]

    public init(id: String, stem: String, choices: [ApiChoice], coveredStepIds: [String]) {
        self.id = id
        self.stem = stem
        self.choices = choices
        self.coveredStepIds = coveredStepIds
    }
}
