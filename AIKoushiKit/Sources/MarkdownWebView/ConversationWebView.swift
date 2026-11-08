//
//  ConversationWebView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import SwiftUI
import WebKit

public struct ConversationWebView: UIViewRepresentable {
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

    public func makeCoordinator() -> ConversationCoordinator {
        ConversationCoordinator()
    }

    public func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLinkTap = onLinkTap
        context.coordinator.onScrollBoxTouch = onScrollBoxTouch
        context.coordinator.update(
            content: content,
            configuration: ConversationConfiguration(environment: context.environment)
        )
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: ConversationCoordinator) {
        coordinator.dismantle(webView)
    }
}
