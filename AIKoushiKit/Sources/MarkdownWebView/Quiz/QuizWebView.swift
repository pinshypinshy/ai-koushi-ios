//
//  QuizWebView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import Foundation
import SwiftUI

public struct QuizWebView: View {
    let content: QuizContent
    let onChoiceTap: (String) -> Void
    let onLinkTap: (URL) -> Void
    let onScrollBoxTouch: (Bool) -> Void

    /// - Parameter onChoiceTap: 回答後も知らせる。選べるかどうかは受け取る側が決める
    public init(
        content: QuizContent,
        onChoiceTap: @escaping (String) -> Void,
        onLinkTap: @escaping (URL) -> Void,
        onScrollBoxTouch: @escaping (Bool) -> Void = { _ in }
    ) {
        self.content = content
        self.onChoiceTap = onChoiceTap
        self.onLinkTap = onLinkTap
        self.onScrollBoxTouch = onScrollBoxTouch
    }

    public var body: some View {
        WebPageView<QuizPage>(
            content: content,
            onMessage: { message in
                switch message {
                case let .choiceTapped(id):
                    onChoiceTap(id)
                case let .linkTapped(string):
                    if let url = BrowserURL.url(string) {
                        onLinkTap(url)
                    }
                }
            },
            onScrollBoxTouch: onScrollBoxTouch
        )
    }
}
