//
//  AIKoushiApp.swift
//  AIKoushi
//
//  Created by 平石悠生 on 2026/10/13.
//

import APIClient
import APIClientLive
import AppFeature
import ComposableArchitecture
import SwiftUI

@main
struct AIKoushiApp: App {
    let store = Store(initialState: AppFeature.State.launching) {
        AppFeature()
    } withDependencies: {
        $0.apiClient = .liveValue
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
