//
//  ConversationView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import SwiftUI
import WebKit

public struct ConversationView: UIViewRepresentable {
    let content: ConversationContent
    let onLinkTap: (URL) -> Void

    public init(content: ConversationContent, onLinkTap: @escaping (URL) -> Void) {
        self.content = content
        self.onLinkTap = onLinkTap
    }

    public func makeCoordinator() -> ConversationCoordinator {
        ConversationCoordinator()
    }

    public func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLinkTap = onLinkTap
        context.coordinator.update(
            content: content,
            configuration: ConversationConfiguration(environment: context.environment)
        )
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: ConversationCoordinator) {
        coordinator.dismantle(webView)
    }
}
