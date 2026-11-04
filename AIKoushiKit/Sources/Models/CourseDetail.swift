//
//  CourseDetail.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/02.
//

public struct CourseDetail: Decodable, Equatable, Identifiable, Sendable {
    public let summary: CourseSummary
    public let currentStepId: String?
    public let steps: [ApiStep]
    public let messages: [ApiMessage]

    public var id: String { summary.id }

    public init(summary: CourseSummary, currentStepId: String?, steps: [ApiStep], messages: [ApiMessage]) {
        self.summary = summary
        self.currentStepId = currentStepId
        self.steps = steps
        self.messages = messages
    }

    private enum CodingKeys: String, CodingKey {
        case currentStepId
        case steps
        case messages
    }

    public init(from decoder: any Decoder) throws {
        // shared/api.ts では CourseSummary を継承しており、要約の項目が同じ階層に並ぶ
        summary = try CourseSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentStepId = try container.decodeIfPresent(String.self, forKey: .currentStepId)
        steps = try container.decode([ApiStep].self, forKey: .steps)
        messages = try container.decode([ApiMessage].self, forKey: .messages)
    }
}
