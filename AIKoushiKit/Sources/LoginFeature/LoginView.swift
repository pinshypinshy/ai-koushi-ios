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
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    googleButton
                        .padding(.top, 40)
                    Group {
                        if store.isGuestFormOpen {
                            guestForm
                        } else {
                            Button("ゲストとしてサインイン") {
                                store.send(.guestSignInButtonTapped)
                            }
                            .buttonStyle(OutlinedButtonStyle())
                        }
                    }
                    .padding(.top, 12)
                    if let message = store.errorMessage {
                        errorMessage(message)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(AppColor.loginBackground)
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image("Logo", bundle: .module)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                Text("AI講師")
                    .font(.title.bold())
                    .foregroundStyle(AppColor.loginTitle)
            }
            // Web版は狭い画面で読点の後に改行を入れている
            Text("参考書をアップロードすると、\nAIが講義と確認テストを作ります")
                .font(.subheadline)
                .foregroundStyle(AppColor.loginSubtleText)
                .multilineTextAlignment(.center)
        }
    }

    // Google でのサインインは段階5で作る。それまでは押せない
    private var googleButton: some View {
        Button {} label: {
            HStack(spacing: 12) {
                Image("GoogleLogo", bundle: .module)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .opacity(0.5)
                Text("Googleでサインイン（未実装）")
                    .foregroundStyle(AppColor.loginSubtleText)
            }
        }
        .buttonStyle(OutlinedButtonStyle())
        .disabled(true)
    }

    private var guestForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("発行された ID とパスワードを入力してください")
                .font(.caption)
                .foregroundStyle(AppColor.loginSubtleText)
            TextField("ID", text: $store.loginId)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .loginId)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .inputField(isFocused: focusedField == .loginId)
                .padding(.top, 12)
            SecureField("パスワード", text: $store.password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { store.send(.loginButtonTapped) }
                .inputField(isFocused: focusedField == .password)
                .padding(.top, 8)
            Button {
                store.send(.loginButtonTapped)
            } label: {
                // 文字を隠すだけにして、送信中もボタンの高さを変えない
                Text("サインイン")
                    .opacity(store.isSubmitting ? 0 : 1)
                    .overlay {
                        if store.isSubmitting {
                            ProgressView()
                                .tint(AppColor.loginDisabledButtonText)
                        }
                    }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!store.canSubmit)
            .padding(.top, 12)
        }
        .padding(16)
        .loginCard(cornerRadius: 12)
    }

    private func errorMessage(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(AppColor.loginErrorText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.loginErrorBackground, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppColor.loginErrorBorder)
            }
    }
}

private struct OutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppColor.loginButtonText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .loginCard(cornerRadius: 12)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isEnabled ? AppColor.loginPrimaryButtonText : AppColor.loginDisabledButtonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isEnabled ? AppColor.loginPrimaryButton : AppColor.loginDisabledButton, in: .rect(cornerRadius: 8))
    }
}

private extension View {
    func loginCard(cornerRadius: CGFloat) -> some View {
        background(AppColor.loginSurface, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AppColor.loginBorder)
            }
    }

    func inputField(isFocused: Bool) -> some View {
        font(.subheadline)
            .foregroundStyle(AppColor.loginInputText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isFocused ? AppColor.loginFocusedBorder : AppColor.loginBorder)
            }
    }
}

#if DEBUG
#Preview("閉じた状態") {
    LoginView(store: Store(initialState: LoginFeature.State()) { LoginFeature() })
}

#Preview("入力枠を開いた状態") {
    var state = LoginFeature.State()
    state.isGuestFormOpen = true
    return LoginView(store: Store(initialState: state) { LoginFeature() })
}

#Preview("送信中") {
    var state = LoginFeature.State(loginId: "guest-01", password: "pass")
    state.isGuestFormOpen = true
    state.isSubmitting = true
    return LoginView(store: Store(initialState: state) { LoginFeature() })
}

#Preview("エラー表示") {
    var state = LoginFeature.State(loginId: "guest-01", errorMessage: "IDまたはパスワードが違います")
    state.isGuestFormOpen = true
    return LoginView(store: Store(initialState: state) { LoginFeature() })
}
#endif
