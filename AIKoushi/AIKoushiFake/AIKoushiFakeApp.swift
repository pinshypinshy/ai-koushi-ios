//
//  AIKoushiFakeApp.swift
//  AIKoushi
//
//  Created by 平石悠生 on 2026/11/07.
//

import APIClient
import APIClientFake
import AppFeature
import ComposableArchitecture
import SwiftUI

@main
struct AIKoushiFakeApp: App {
    let store = Store(initialState: AppFeature.State.launching) {
        AppFeature()
    } withDependencies: {
        $0.apiClient = .fake
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
