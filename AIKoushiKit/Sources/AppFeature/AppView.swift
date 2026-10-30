//
//  AppView.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/30.
//

import ComposableArchitecture
import LoginFeature
import SwiftUI

public struct AppView: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.state {
            case .launching:
                ProgressView("読み込み中")

            case let .launchFailed(error):
                ContentUnavailableView {
                    Label("読み込めませんでした", systemImage: error == .network ? "wifi.exclamationmark" : "exclamationmark.triangle")
                } description: {
                    switch error {
                    case .network:
                        Text("通信できませんでした。ネットワーク接続を確認してください。")
                    case .other:
                        Text("時間をおいて再度お試しください。")
                    }
                } actions: {
                    Button("再試行") {
                        store.send(.retryButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .login:
                if let loginStore = store.scope(state: \.login, action: \.login) {
                    LoginView(store: loginStore)
                }

            case .loggingOut:
                ProgressView("ログアウトしています")

            case .main:
                if let mainStore = store.scope(state: \.main, action: \.main) {
                    MainView(store: mainStore)
                }
            }
        }
        .task { store.send(.task) }
    }
}

// .task が bootstrap を呼んで状態を変えてしまうため、Reducer を空にして見た目だけを確かめる。
// 各画面の操作は LoginView・MainView のプレビューで確かめる
#Preview("読み込み中") {
    AppView(store: Store(initialState: .launching) { EmptyReducer() })
}

#Preview("起動の失敗（通信エラー）") {
    AppView(store: Store(initialState: .launchFailed(.network)) { EmptyReducer() })
}

#Preview("起動の失敗（その他）") {
    AppView(store: Store(initialState: .launchFailed(.other)) { EmptyReducer() })
}

#Preview("ログイン（セッション切れ）") {
    AppView(store: Store(initialState: .login(LoginFeature.State(errorMessage: AppFeature.sessionExpiredMessage))) { EmptyReducer() })
}

#Preview("ログアウト中") {
    AppView(store: Store(initialState: .loggingOut) { EmptyReducer() })
}

#Preview("メイン画面") {
    AppView(store: Store(initialState: .main(MainFeature.State(bootstrap: .preview(courses: .preview)))) { EmptyReducer() })
}
