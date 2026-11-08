//
//  Theme.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/31.
//

import SharedUI
import SwiftUI
import UIKit

struct Theme: Equatable, Encodable {
    // 名前は WebRenderer/src/core/theme.ts の colorNames と対になる
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
        var choiceBackground: String
        var choiceBorder: String
        var choiceLabelBackground: String
        var choiceLabelFilledText: String
        var choiceSelected: String
        var choiceSelectedBackground: String
        var answerCorrect: String
        var answerCorrectBackground: String
        var answerIncorrect: String
        var answerIncorrectBackground: String
        var explanationBackground: String
    }

    var colors: Colors
    var fontSize: Double
}

extension Theme {
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
                tableHeaderBackground: css(AppColor.tableHeaderBackground),
                choiceBackground: css(AppColor.choiceBackground),
                choiceBorder: css(AppColor.choiceBorder),
                choiceLabelBackground: css(AppColor.choiceLabelBackground),
                choiceLabelFilledText: css(AppColor.choiceLabelFilledText),
                choiceSelected: css(AppColor.choiceSelected),
                choiceSelectedBackground: css(AppColor.choiceSelectedBackground),
                answerCorrect: css(AppColor.answerCorrect),
                answerCorrectBackground: css(AppColor.answerCorrectBackground),
                answerIncorrect: css(AppColor.answerIncorrect),
                answerIncorrectBackground: css(AppColor.answerIncorrectBackground),
                explanationBackground: css(AppColor.explanationBackground)
            ),
            fontSize: UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits).pointSize
        )
    }
}
