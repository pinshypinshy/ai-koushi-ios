//
//  ConversationConfiguration.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import SharedUI
import SwiftUI
import UIKit

struct ConversationConfiguration: Equatable, Encodable {
    // 名前は WebRenderer/src/commands.ts の colorNames と対になる
    struct Colors: Equatable, Encodable {
        var text: String
        var secondaryText: String
        var link: String
        var error: String
        var border: String
        var userMessageBackground: String
        var userMessageText: String
        var codeBackground: String
        var codeBlockBackground: String
        var codeBlockText: String
        var tableHeaderBackground: String
    }

    var colors: Colors
    var fontSize: Double
    var waitingText: String
}

extension ConversationConfiguration {
    init(environment: EnvironmentValues) {
        func css(_ color: Color) -> String {
            let resolved = color.resolve(in: environment)
            return "color(srgb \(resolved.red) \(resolved.green) \(resolved.blue) / \(resolved.opacity))"
        }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(environment.dynamicTypeSize))
        self.init(
            colors: Colors(
                text: css(AppColor.primaryText),
                secondaryText: css(AppColor.secondaryText),
                link: css(AppColor.link),
                error: css(AppColor.error),
                border: css(AppColor.border),
                userMessageBackground: css(AppColor.userMessageBackground),
                userMessageText: css(AppColor.userMessageText),
                codeBackground: css(AppColor.codeBackground),
                codeBlockBackground: css(AppColor.codeBlockBackground),
                codeBlockText: css(AppColor.codeBlockText),
                tableHeaderBackground: css(AppColor.tableHeaderBackground)
            ),
            fontSize: UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits).pointSize,
            waitingText: "応答を待っています"
        )
    }
}
