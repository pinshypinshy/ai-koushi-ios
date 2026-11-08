//
//  RenderingHarness.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import Foundation
@testable import MarkdownWebView
import SwiftUI
import Testing
import UIKit
import WebKit

/// ページを実際の WKWebView に読ませ、描かれた結果を JavaScript で調べる
@MainActor
final class RenderingHarness<Page: PageDefinition> {
    let coordinator = WebPageCoordinator<Page>()
    let webView: WKWebView
    // ウィンドウに無い WebView は既定で処理が止められるため（WKPreferences.inactiveSchedulingPolicy）、実際のアプリと同じくウィンドウに入れる
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    private(set) var errors: [(kind: CommonMessage.ErrorKind, message: String)] = []

    init() {
        webView = coordinator.makeWebView()
        webView.frame = window.bounds
        window.addSubview(webView)
        window.isHidden = false
        coordinator.onError = { [weak self] kind, message in
            self?.errors.append((kind, message))
        }
    }

    func show(_ content: Page.Content) {
        coordinator.update(content: content, theme: Theme(environment: EnvironmentValues()))
    }

    /// 式の値を JSON の文字列で返す
    func evaluate(_ expression: String) async throws -> String {
        let result = try await webView.callAsyncJavaScript(
            "return JSON.stringify(\(expression))",
            arguments: [:],
            contentWorld: .page
        )
        return try #require(result as? String)
    }

    // 他のビルドなどで重いときは、WebView の読み込みに10秒以上かかることがあるため長めに待つ
    func waitUntil(_ condition: String, timeout: Duration = .seconds(30)) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if try await evaluate("Boolean(\(condition))") == "true" { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("待っている条件が満たされなかった：\(condition)")
        throw CancellationError()
    }

    func waitUntil(timeout: Duration = .seconds(30), _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("待っている条件が満たされなかった")
        throw CancellationError()
    }
}
