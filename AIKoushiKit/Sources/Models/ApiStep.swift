//
//  ApiStep.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/02.
//

public enum StepStatus: String, Decodable, Equatable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed
}

// objective・keyPoints・sourceRef・completedAt は画面で使わないため宣言しない（宣言しない項目は読み込み時に無視される）
public struct ApiStep: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let orderIndex: Int
    public let title: String
    public let status: StepStatus

    public init(id: String, orderIndex: Int, title: String, status: StepStatus) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
        self.status = status
    }
}
