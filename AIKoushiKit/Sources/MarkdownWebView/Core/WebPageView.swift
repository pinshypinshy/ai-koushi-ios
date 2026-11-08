//
//  WebPageView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import SwiftUI
import WebKit

struct WebPageView<Page: PageDefinition>: UIViewRepresentable {
    let content: Page.Content
    let onMessage: (Page.Message) -> Void
    let onScrollBoxTouch: (Bool) -> Void

    func makeCoordinator() -> WebPageCoordinator<Page> {
        WebPageCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onMessage = onMessage
        context.coordinator.onScrollBoxTouch = onScrollBoxTouch
        context.coordinator.update(content: content, theme: Theme(environment: context.environment))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: WebPageCoordinator<Page>) {
        coordinator.dismantle(webView)
    }
}
