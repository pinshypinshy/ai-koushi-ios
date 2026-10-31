//
//  AppColor.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import SwiftUI

// 配色は未決（§8）。決まるまでは iOS 標準の色を当てておく
public enum AppColor {
    public static let error = Color.red
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary

    // Web版（Tailwind v4）の色を sRGB にした値。暗い配色は Web版に無く、iOS版で決めた（§3.1）
    public static let loginBackground = color(light: 0xF1F5F9, dark: 0x020618)
    public static let loginSurface = color(light: 0xFFFFFF, dark: 0x0F172B)
    public static let loginBorder = color(light: 0xCAD5E2, dark: 0x314158)
    public static let loginFocusedBorder = color(light: 0x7C86FF, dark: 0x7C86FF)
    public static let loginTitle = color(light: 0x0F172B, dark: 0xF1F5F9)
    public static let loginButtonText = color(light: 0x314158, dark: 0xE2E8F0)
    public static let loginSubtleText = color(light: 0x62748E, dark: 0x90A1B9)
    public static let loginInputText = color(light: 0x1D293D, dark: 0xF1F5F9)
    public static let loginPrimaryButton = color(light: 0x0F172B, dark: 0xF1F5F9)
    public static let loginPrimaryButtonText = color(light: 0xFFFFFF, dark: 0x0F172B)
    public static let loginDisabledButton = color(light: 0xE2E8F0, dark: 0x1D293D)
    public static let loginDisabledButtonText = color(light: 0x90A1B9, dark: 0x62748E)
    public static let loginErrorBackground = color(light: 0xFFF1F2, dark: 0x4D0218)
    public static let loginErrorBorder = color(light: 0xFFCCD3, dark: 0xA50036)
    public static let loginErrorText = color(light: 0xC70036, dark: 0xFFA1AD)

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            let rgb = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    public static let sidebarBackground = Color(uiColor: .systemBackground)
    public static let selectedRowBackground = Color(uiColor: .secondarySystemFill)

    public static let usageTrack = Color(uiColor: .systemFill)
    public static let usageNormal = Color.accentColor
    public static let usageWarning = Color.orange
    public static let usageLimit = Color.red
}
