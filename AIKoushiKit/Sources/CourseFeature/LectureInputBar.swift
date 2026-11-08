//
//  LectureInputBar.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/11/06.
//

import ComposableArchitecture
import SharedUI
import SwiftUI

/// §3.2 の入力欄
struct LectureInputBar: View {
    @Bindable var store: StoreOf<LectureFeature>
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("プロンプトを入力", text: $store.draft.sending(\.draftChanged), axis: .vertical)
                .lineLimit(1...5)
                .focused(isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColor.inputBackground, in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(AppColor.inputBorder)
                }

            Button {
                store.send(.sendButtonTapped)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        store.canSend ? AppColor.primaryButtonText : AppColor.disabledButtonText,
                        store.canSend ? AppColor.primaryButton : AppColor.disabledButton
                    )
            }
            .disabled(!store.canSend)
            .accessibilityLabel("送信")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
