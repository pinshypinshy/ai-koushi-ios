//
//  ServerURL.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/29.
//

import Foundation

public enum ServerURL {
    // 固定の文字列リテラルで、URL として解釈できないことが無いため強制アンラップしている
    public static let production = URL(string: "https://ai-koushi.yuki-hiraishi.com")!
}
