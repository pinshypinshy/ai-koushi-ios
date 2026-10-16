//
//  ApiError.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

public struct ApiError: Decodable, Equatable, Sendable {
  public let error: String
  public let message: String

  public init(error: String, message: String) {
    self.error = error
    self.message = message
  }
}
