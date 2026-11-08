//
//  CourseToolbar.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/08.
//

import SharedUI
import SwiftUI

/// 一番上の行。タブごとに NavigationStack を持つため、どのタブにも同じものを付ける（§3.5）
struct CourseToolbar: ViewModifier {
    let title: String
    let onMenuTap: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onMenuTap) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(AppColor.toolbarIcon)
                    }
                    .accessibilityLabel("サイドバーを開く")
                }
            }
    }
}

extension View {
    func courseToolbar(title: String, onMenuTap: @escaping () -> Void) -> some View {
        modifier(CourseToolbar(title: title, onMenuTap: onMenuTap))
    }
}
