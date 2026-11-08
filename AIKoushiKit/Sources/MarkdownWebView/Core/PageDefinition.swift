//
//  PageDefinition.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

/// ページごとに決めるもの（ADR 0009）。WebRenderer/src/<name>/ と対になる
protocol PageDefinition {
    associatedtype Content: Equatable
    associatedtype Command: Encodable & Equatable
    associatedtype Message: Decodable & Equatable

    /// 同梱の HTML のファイル名と、JavaScript からの知らせの受け口の名前
    static var name: String { get }

    /// 前回送った内容から今回の内容にするための命令。delivered が nil なら、まだ何も送っていない
    static func commands(from delivered: Content?, to content: Content) -> [Command]
}
