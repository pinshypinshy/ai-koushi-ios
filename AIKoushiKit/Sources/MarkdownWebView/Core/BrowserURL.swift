//
//  BrowserURL.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import Foundation

/// ページで押されたリンクのうち、ブラウザで開いてよいものだけを URL にする（§3.2）
enum BrowserURL {
    static func url(_ string: String) -> URL? {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
