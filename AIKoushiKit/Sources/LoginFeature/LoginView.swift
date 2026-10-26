//
//  LoginView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/17.
//

import ComposableArchitecture
import SharedUI
import SwiftUI

public struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    @FocusState private var focusedField: Field?

    private enum Field {
        case loginId
        case password
    }

    public init(store: StoreOf<LoginFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("ログインID", text: $store.loginId)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .loginId)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            SecureField("パスワード", text: $store.password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { store.send(.loginButtonTapped) }

            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppColor.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                store.send(.loginButtonTapped)
            } label: {
                Group {
                    if store.isSubmitting {
                        ProgressView()
                    } else {
                        Text("ログイン")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canSubmit)
        }
        .textFieldStyle(.roundedBorder)
        .padding()
    }
}

#Preview("入力前") {
    LoginView(store: Store(initialState: LoginFeature.State()) { LoginFeature() })
}

#Preview("送信中") {
    var state = LoginFeature.State(loginId: "guest-01", password: "pass")
    state.isSubmitting = true
    return LoginView(store: Store(initialState: state) { LoginFeature() })
}

#Preview("エラー表示") {
    LoginView(
        store: Store(initialState: LoginFeature.State(loginId: "guest-01", errorMessage: "IDまたはパスワードが違います")) {
            LoginFeature()
        }
    )
}
