//
//  WebPageHost.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import Foundation
import os
import UIKit
import WebKit

/// WebKit との接点。JSON の文字列とデータだけを扱い、型を付けるのは WebPageCoordinator が行う。
/// WebKit からの呼び出しを受けるため、型引数を持たせない
@MainActor
final class WebPageHost: NSObject {
    let pageName: String

    var onMessage: (Data) -> Void = { _ in }
    /// ページを読み直し始めたとき。それまでに送ったものは消えている
    var onReload: () -> Void = {}
    var onError: (CommonMessage.ErrorKind, String) -> Void = WebPageHost.reportError

    private weak var webView: WKWebView?

    init(pageName: String) {
        self.pageName = pageName
    }

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: pageName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.scrollView.keyboardDismissMode = .interactive
        let tap = UITapGestureRecognizer(target: self, action: #selector(webViewTapped(_:)))
        // リンクの操作やスクロールを妨げない（§3.2）
        tap.cancelsTouchesInView = false
        tap.delegate = self
        webView.addGestureRecognizer(tap)
        #if DEBUG
        webView.isInspectable = true
        #endif
        self.webView = webView
        load(webView)
        return webView
    }

    func dismantle(_ webView: WKWebView) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: pageName)
    }

    func send(json: String) {
        // 内容をコードに埋め込まず、引数として渡す
        webView?.callAsyncJavaScript(
            "page.apply(json)",
            arguments: ["json": json],
            in: nil,
            in: .page
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.onError(.script, "命令を実行できない：\(error)")
            }
        }
    }

    @objc private func webViewTapped(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.window?.endEditing(true)
    }

    private func load(_ webView: WKWebView) {
        onReload()
        guard let url = pageURL else {
            onError(.script, "同梱した \(pageName).html が見つからない")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    var pageURL: URL? {
        Bundle.module.url(forResource: pageName, withExtension: "html", subdirectory: "WebRenderer")
    }

    nonisolated private static let logger = Logger(subsystem: "AIKoushiKit", category: "MarkdownWebView")

    /// コードの誤り（script・command）は開発中に止めて気づかせる。数式の誤りは内容の問題なので記録だけにする（ADR 0003）
    nonisolated static func reportError(_ kind: CommonMessage.ErrorKind, _ message: String) {
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

extension WebPageHost: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

extension WebPageHost: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        do {
            onMessage(try JSONSerialization.data(withJSONObject: message.body))
        } catch {
            onError(.command, "JavaScript から届いたものを JSON にできない：\(error)")
        }
    }
}

extension WebPageHost: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        // 同梱したページ以外へは移らない。リンクは JavaScript が Swift へ渡す（§3.2）
        decisionHandler(navigationAction.request.url == pageURL ? .allow : .cancel)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // メモリが足りずに WebView の処理が終わると、白い画面のままになる。読み込み直して全体を送り直す
        load(webView)
    }
}
