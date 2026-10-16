//
//  CourseSummary.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

public enum CourseStatus: String, Decodable, Equatable, Sendable {
  case generating
  case ready
  case failed
}

public enum QuizStatus: String, Decodable, Equatable, Sendable {
  case pending
  case ready
  case failed
}

public enum GeneratingPhase: String, Decodable, Equatable, Sendable {
  case outline
  case quiz
}

public struct CourseSummary: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let status: CourseStatus
  public let quizStatus: QuizStatus
  public let phase: GeneratingPhase?
  public let errorMessage: String?
  public let totalSteps: Int
  public let completedSteps: Int
  /// ミリ秒のエポック時刻
  public let updatedAt: Int

  public init(
    id: String,
    title: String,
    status: CourseStatus,
    quizStatus: QuizStatus,
    phase: GeneratingPhase?,
    errorMessage: String?,
    totalSteps: Int,
    completedSteps: Int,
    updatedAt: Int
  ) {
    self.id = id
    self.title = title
    self.status = status
    self.quizStatus = quizStatus
    self.phase = phase
    self.errorMessage = errorMessage
    self.totalSteps = totalSteps
    self.completedSteps = completedSteps
    self.updatedAt = updatedAt
  }
}
