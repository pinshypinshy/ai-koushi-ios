//
//  AppSecondaryButtonStyle.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import SwiftUI

public struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? AppColor.secondaryButtonText : AppColor.disabledButtonText)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppColor.secondaryButtonBackground, in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(AppColor.secondaryButtonBorder)
            }
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == AppSecondaryButtonStyle {
    public static var appSecondary: AppSecondaryButtonStyle { AppSecondaryButtonStyle() }
}
