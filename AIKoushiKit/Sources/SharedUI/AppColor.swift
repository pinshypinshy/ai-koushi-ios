//
//  AppColor.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import SwiftUI

// 配色の方針は §5
public enum AppColor {
    // 標準の部品（ボタン・ProgressView など）には、AppView の .tint で渡す。
    // Color.accentColor はアセットの色で .tint を反映しないため、ここでは使わない
    public static let accent = color(light: Tailwind.indigo600, dark: Tailwind.indigo400)
    public static let error = color(light: Tailwind.rose600, dark: Tailwind.rose400)
    public static let primaryText = color(light: Tailwind.slate800, dark: Tailwind.slate100)
    public static let secondaryText = color(light: Tailwind.slate500, dark: Tailwind.slate400)
    public static let link = color(light: Tailwind.indigo600, dark: Tailwind.indigo400)
    public static let border = color(light: Tailwind.slate200, dark: Tailwind.slate800)
    public static let toolbarIcon = color(light: Tailwind.slate600, dark: Tailwind.slate400)

    public static let primaryButton = color(light: Tailwind.slate900, dark: Tailwind.slate100)
    public static let primaryButtonText = color(light: Tailwind.white, dark: Tailwind.slate900)
    public static let disabledButton = color(light: Tailwind.slate200, dark: Tailwind.slate800)
    public static let disabledButtonText = color(light: Tailwind.slate400, dark: Tailwind.slate500)
    public static let secondaryButtonBackground = color(light: Tailwind.white, dark: Tailwind.slate900)
    public static let secondaryButtonBorder = color(light: Tailwind.slate300, dark: Tailwind.slate700)
    public static let secondaryButtonText = color(light: Tailwind.slate700, dark: Tailwind.slate200)

    // サイドバーは暗い配色で描く（SidebarView）。ここに無い色は、他の色の暗い配色の値が使われる
    public static let sidebarBackground = fixed(Tailwind.slate900)
    public static let selectedRowBackground = fixed(Tailwind.slate800)
    public static let usageTrack = fixed(Tailwind.slate800)
    public static let usageNormal = accent
    public static let usageWarning = fixed(Tailwind.amber400)
    public static let usageLimit = fixed(Tailwind.rose400)

    public static let stepCompleted = color(light: Tailwind.emerald600, dark: Tailwind.emerald400)
    public static let stepCurrent = color(light: Tailwind.indigo500, dark: Tailwind.indigo400)
    public static let stepNotStarted = color(light: Tailwind.slate400, dark: Tailwind.slate500)
    public static let checkOn = accent
    public static let checkOff = color(light: Tailwind.slate300, dark: Tailwind.slate700)
    public static let inputBackground = color(light: Tailwind.white, dark: Tailwind.slate900)
    public static let inputBorder = color(light: Tailwind.slate300, dark: Tailwind.slate700)

    public static let userMessageBackground = fixed(Tailwind.indigo600)
    public static let userMessageText = fixed(Tailwind.white)
    public static let codeBackground = color(light: Tailwind.slate100, dark: Tailwind.slate800)
    public static let codeBlockBackground = fixed(Tailwind.slate900)
    public static let codeBlockText = fixed(Tailwind.slate100)
    public static let tableHeaderBackground = color(light: Tailwind.slate50, dark: Tailwind.slate900)

    public static let choiceBackground = color(light: Tailwind.white, dark: Tailwind.slate900)
    public static let choiceBorder = color(light: Tailwind.slate200, dark: Tailwind.slate800)
    public static let choiceLabelBackground = color(light: Tailwind.slate100, dark: Tailwind.slate800)
    public static let choiceLabelFilledText = fixed(Tailwind.white)
    public static let choiceSelected = fixed(Tailwind.indigo600)
    public static let choiceSelectedBackground = color(light: Tailwind.indigo50, dark: Tailwind.indigo950)
    public static let answerCorrect = fixed(Tailwind.emerald600)
    public static let answerCorrectBackground = color(light: Tailwind.emerald50, dark: Tailwind.emerald950)
    public static let answerIncorrect = fixed(Tailwind.rose500)
    public static let answerIncorrectBackground = color(light: Tailwind.rose50, dark: Tailwind.rose950)
    public static let explanationBackground = color(light: Tailwind.slate50, dark: Tailwind.slate900)
    public static let reviewModeBackground = color(light: Tailwind.amber100, dark: Tailwind.amber950)
    public static let reviewModeText = color(light: Tailwind.amber800, dark: Tailwind.amber200)

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

    private static func fixed(_ rgb: UInt32) -> Color {
        color(light: rgb, dark: rgb)
    }

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
}

// Web版（Tailwind v4）の oklch の色を sRGB にした値
private enum Tailwind {
    static let white: UInt32 = 0xFFFFFF

    static let slate50: UInt32 = 0xF8FAFC
    static let slate100: UInt32 = 0xF1F5F9
    static let slate200: UInt32 = 0xE2E8F0
    static let slate300: UInt32 = 0xCAD5E2
    static let slate400: UInt32 = 0x90A1B9
    static let slate500: UInt32 = 0x62748E
    static let slate600: UInt32 = 0x45556C
    static let slate700: UInt32 = 0x314158
    static let slate800: UInt32 = 0x1D293D
    static let slate900: UInt32 = 0x0F172B

    static let indigo50: UInt32 = 0xEEF2FF
    static let indigo400: UInt32 = 0x7C86FF
    static let indigo500: UInt32 = 0x615FFF
    static let indigo600: UInt32 = 0x4F39F6
    static let indigo950: UInt32 = 0x1E1A4D

    static let emerald50: UInt32 = 0xECFDF5
    static let emerald400: UInt32 = 0x00D492
    static let emerald600: UInt32 = 0x009966
    static let emerald950: UInt32 = 0x002C22

    static let rose50: UInt32 = 0xFFF1F2
    static let rose400: UInt32 = 0xFF637E
    static let rose500: UInt32 = 0xFF2056
    static let rose600: UInt32 = 0xEC003F
    static let rose950: UInt32 = 0x4D0218

    static let amber100: UInt32 = 0xFEF3C6
    static let amber200: UInt32 = 0xFEE685
    static let amber400: UInt32 = 0xFFB900
    static let amber800: UInt32 = 0x973C00
    static let amber950: UInt32 = 0x461901
}
