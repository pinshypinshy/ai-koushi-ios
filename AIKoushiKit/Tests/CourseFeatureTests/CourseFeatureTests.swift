//
//  CourseFeatureTests.swift
//  AIKoushiKit
//
//  Created by 平石悠生 on 2026/10/29.
//

import ComposableArchitecture
@testable import CourseFeature
import Foundation
import Testing

@MainActor
struct CourseFeatureTests {
    @Test func menuButtonTapped_親にサイドバーを開くよう頼む() async {
        let store = TestStore(initialState: CourseFeature.State(course: nil)) {
            CourseFeature()
        }

        await store.send(.menuButtonTapped)
        await store.receive(\.delegate.sidebarRequested)
    }

    @Test func openWebButtonTapped_本番のURLを開く() async {
        let openedURL = LockIsolated<URL?>(nil)
        let store = TestStore(initialState: CourseFeature.State(course: nil)) {
            CourseFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                openedURL.setValue(url)
                return true
            }
        }

        await store.send(.openWebButtonTapped)
        #expect(openedURL.value == URL(string: "https://ai-koushi.yuki-hiraishi.com"))
    }
}
