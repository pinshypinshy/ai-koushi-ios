//
//  WebPageCoordinator.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import Foundation
import WebKit

/// どこまで送ったかは WebView の内部の記録なので、TCA の State ではなくここで持つ
@MainActor
final class WebPageCoordinator<Page: PageDefinition> {
    var onMessage: (Page.Message) -> Void = { _ in }
    var onScrollBoxTouch: (Bool) -> Void = { _ in }
    var onError: (CommonMessage.ErrorKind, String) -> Void = WebPageHost.reportError

    private let host = WebPageHost(pageName: Page.name)
    private var isReady = false
    private var content: Page.Content?
    private var theme: Theme?
    private var deliveredContent: Page.Content?
    private var deliveredTheme: Theme?

    init() {
        host.onMessage = { [weak self] in self?.receive($0) }
        host.onReload = { [weak self] in self?.reset() }
        host.onError = { [weak self] in self?.onError($0, $1) }
    }

    func makeWebView() -> WKWebView {
        host.makeWebView()
    }

    func dismantle(_ webView: WKWebView) {
        host.dismantle(webView)
    }

    func update(content: Page.Content, theme: Theme) {
        self.content = content
        self.theme = theme
        send()
    }

    private func reset() {
        isReady = false
        deliveredContent = nil
        deliveredTheme = nil
    }

    private func send() {
        guard isReady, let content, let theme else { return }

        var commands: [OutgoingCommand<Page.Command>] = []
        if theme != deliveredTheme {
            commands.append(.configure(theme))
        }
        commands += Page.commands(from: deliveredContent, to: content).map(OutgoingCommand.page)
        guard !commands.isEmpty else { return }

        let json: String
        do {
            json = String(decoding: try JSONEncoder().encode(commands), as: UTF8.self)
        } catch {
            onError(.command, "命令を JSON にできない：\(error)")
            return
        }
        deliveredContent = content
        deliveredTheme = theme
        host.send(json: json)
    }

    private func receive(_ data: Data) {
        let message: IncomingMessage<Page.Message>
        do {
            message = try IncomingMessage(json: data)
        } catch {
            onError(.command, "JavaScript から届いたものを解釈できない：\(error)")
            return
        }
        switch message {
        case .common(.ready):
            isReady = true
            send()
        case let .common(.scrollBoxTouched(canScrollBack)):
            onScrollBoxTouch(canScrollBack)
        case let .common(.error(kind, message)):
            onError(kind, message)
        case let .page(message):
            onMessage(message)
        }
    }
}
