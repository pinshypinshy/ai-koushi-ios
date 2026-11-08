//
//  ConversationWebView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import Foundation
import SwiftUI

public struct ConversationWebView: View {
    let content: ConversationContent
    let onLinkTap: (URL) -> Void
    let onScrollBoxTouch: (Bool) -> Void

    /// - Parameter onScrollBoxTouch: 触れた枠をまだ右へ戻せるときに true、それ以外で false を受け取る
    public init(
        content: ConversationContent,
        onLinkTap: @escaping (URL) -> Void,
        onScrollBoxTouch: @escaping (Bool) -> Void = { _ in }
    ) {
        self.content = content
        self.onLinkTap = onLinkTap
        self.onScrollBoxTouch = onScrollBoxTouch
    }

    public var body: some View {
        WebPageView<ConversationPage>(
            content: content,
            onMessage: { message in
                switch message {
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
