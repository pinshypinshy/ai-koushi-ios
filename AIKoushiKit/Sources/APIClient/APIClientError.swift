//
//  APIClientError.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import Models

/// 401 の意味は API ごとに違う（§4.2・§4.4）ので、ここでは解釈しない
public enum APIClientError: Error, Equatable, Sendable {
  case http(status: Int, body: ApiError?)
  case network
  case decoding
}
