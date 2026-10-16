//
//  ApiUser.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

public struct ApiUser: Decodable, Equatable, Sendable {
  public let id: String
  public let email: String
  public let displayName: String

  public init(id: String, email: String, displayName: String) {
    self.id = id
    self.email = email
    self.displayName = displayName
  }
}
