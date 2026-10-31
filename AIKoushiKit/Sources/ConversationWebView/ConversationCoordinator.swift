//
//  ConversationCoordinator.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import Foundation
import os
import WebKit

/// どこまで送ったかは WebView の内部の記録なので、TCA の State ではなくここで持つ
@MainActor
public final class ConversationCoordinator: NSObject {
    static let messageHandlerName = "conversation"

    var onLinkTap: (URL) -> Void = { _ in }
    var onError: (WebMessage.ErrorKind, String) -> Void = ConversationCoordinator.reportError

    private weak var webView: WKWebView?
    private var isReady = false
    private var content: ConversationContent?
    private var configuration: ConversationConfiguration?
    private var deliveredContent: ConversationContent?
    private var deliveredConfiguration: ConversationConfiguration?

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: Self.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        #if DEBUG
        webView.isInspectable = true
        #endif
        self.webView = webView
        load(webView)
        return webView
    }

    func dismantle(_ webView: WKWebView) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
    }

    func update(content: ConversationContent, configuration: ConversationConfiguration) {
        self.content = content
        self.configuration = configuration
        send()
    }

    private func load(_ webView: WKWebView) {
        isReady = false
        deliveredContent = nil
        deliveredConfiguration = nil
        guard let url = Self.pageURL else {
            onError(.script, "同梱した index.html が見つからない")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func send() {
        guard isReady, let webView, let content, let configuration else { return }

        var commands: [ConversationCommand] = []
        if configuration != deliveredConfiguration {
            commands.append(.configure(configuration))
        }
        commands += ConversationCommand.commands(from: deliveredContent, to: content)
        guard !commands.isEmpty else { return }

        let json: String
        do {
            json = String(decoding: try JSONEncoder().encode(commands), as: UTF8.self)
        } catch {
            onError(.command, "命令を JSON にできない：\(error)")
            return
        }
        deliveredContent = content
        deliveredConfiguration = configuration
        // 発言の内容をコードに埋め込まず、引数として渡す
        webView.callAsyncJavaScript(
            "conversation.apply(json)",
            arguments: ["json": json],
            in: nil,
            in: .page
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.onError(.script, "命令を実行できない：\(error)")
            }
        }
    }

    private func receive(_ message: WebMessage) {
        switch message {
        case .ready:
            isReady = true
            send()
        case let .linkTapped(string):
            if let url = WebMessage.browserURL(string) {
                onLinkTap(url)
            }
        case let .error(kind, message):
            onError(kind, message)
        }
    }

    static var pageURL: URL? {
        Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "WebRenderer")
    }

    nonisolated private static let logger = Logger(subsystem: "AIKoushiKit", category: "ConversationWebView")

    /// コードの誤り（script・command）は開発中に止めて気づかせる。数式の誤りは内容の問題なので記録だけにする（ADR 0003）
    nonisolated private static func reportError(_ kind: WebMessage.ErrorKind, _ message: String) {
        #if DEBUG
        switch kind {
        case .math:
            logger.warning("数式を描けない：\(message, privacy: .public)")
        case .script, .command:
            logger.error("\(kind.rawValue, privacy: .public)：\(message, privacy: .public)")
            assertionFailure("\(kind.rawValue)：\(message)")
        }
        #endif
    }
}

extension ConversationCoordinator: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message.body)
            receive(try JSONDecoder().decode(WebMessage.self, from: data))
        } catch {
            onError(.command, "JavaScript から届いたものを解釈できない：\(error)")
        }
    }
}

extension ConversationCoordinator: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        // 同梱したページ以外へは移らない。リンクは JavaScript が Swift へ渡す（§3.2）
        decisionHandler(navigationAction.request.url == Self.pageURL ? .allow : .cancel)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // メモリが足りずに WebView の処理が終わると、白い画面のままになる。読み込み直して全体を送り直す
        load(webView)
    }
}
