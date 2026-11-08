//
//  AppPrimaryButtonStyle.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import SwiftUI

// .borderedProminent は文字が白に固定され、暗い配色の明るい塗りの上で読めなくなるため自前で描く（§5）
public struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? AppColor.primaryButtonText : AppColor.disabledButtonText)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isEnabled ? AppColor.primaryButton : AppColor.disabledButton, in: .capsule)
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == AppPrimaryButtonStyle {
    public static var appPrimary: AppPrimaryButtonStyle { AppPrimaryButtonStyle() }
}
