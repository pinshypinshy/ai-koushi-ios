//
//  UsageMeterView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/27.
//

import Models
import SharedUI
import SwiftUI

struct UsageMeterView: View {
    let usage: UsageSummary

    var body: some View {
        let meter = UsageMeter(usage: usage)
        VStack(alignment: .leading, spacing: 10) {
            Text("今月の利用状況")
                .font(.caption.bold())
                .foregroundStyle(AppColor.secondaryText)
            bar(label: "AI利用額", value: "\(meter.costPercent)%", percent: meter.costPercent, level: meter.costLevel)
            bar(label: "講義作成", value: "\(usage.courses) / \(usage.courseLimit) 件", percent: meter.coursePercent, level: meter.courseLevel)
            if let notice = meter.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(color(for: meter.overallLevel))
            }
        }
    }

    private func bar(label: String, value: String, percent: Int, level: UsageMeter.Level) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(value)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(AppColor.secondaryText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.usageTrack)
                    Capsule()
                        .fill(color(for: level))
                        // 0% でない限り帯を見える幅まで残す。わずかな消費が 0% と見分けられなくなるため（Web版と同じ）
                        .frame(width: geometry.size.width * CGFloat(percent > 0 ? max(percent, 2) : 0) / 100)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }

    private func color(for level: UsageMeter.Level) -> Color {
        switch level {
        case .normal: AppColor.usageNormal
        case .warning: AppColor.usageWarning
        case .limit: AppColor.usageLimit
        }
    }
}
