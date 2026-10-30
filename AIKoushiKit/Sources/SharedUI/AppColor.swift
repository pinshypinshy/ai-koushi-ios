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

    public static let sidebarBackground = Color(uiColor: .systemBackground)
    public static let selectedRowBackground = Color(uiColor: .secondarySystemFill)
    public static let dimming = Color.black.opacity(0.4)

    public static let usageTrack = Color(uiColor: .systemFill)
    public static let usageNormal = Color.accentColor
    public static let usageWarning = Color.orange
    public static let usageLimit = Color.red
}
