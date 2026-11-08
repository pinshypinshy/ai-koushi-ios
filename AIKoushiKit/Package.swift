// swift-tools-version: 6.2

import PackageDescription

let tca: Target.Dependency = .product(name: "ComposableArchitecture", package: "swift-composable-architecture")

let package = Package(
    name: "AIKoushiKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "APIClientLive", targets: ["APIClientLive"]),
        .library(name: "APIClientFake", targets: ["APIClientFake"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2"),
    ],
    targets: [
        .target(name: "Models"),
        .target(name: "AppConfig"),
        .target(name: "APIClient", dependencies: ["Models", tca]),
        .target(name: "APIClientLive", dependencies: ["APIClient", "AppConfig", "Models", tca]),
        .target(name: "APIClientFake", dependencies: ["APIClient", "Models"]),
        .target(name: "SharedUI", dependencies: ["Models"]),
        .target(name: "MarkdownWebView", dependencies: ["SharedUI"], resources: [.copy("Resources/WebRenderer")]),
        .target(name: "LoginFeature", dependencies: ["APIClient", "Models", "SharedUI", tca], resources: [.process("Resources")]),
        .target(name: "SidebarFeature", dependencies: ["APIClient", "Models", "SharedUI", tca]),
        .target(name: "CourseFeature", dependencies: ["APIClient", "AppConfig", "MarkdownWebView", "Models", "SharedUI", tca]),
        .target(name: "AppFeature", dependencies: ["LoginFeature", "SidebarFeature", "CourseFeature", "APIClient", "Models", "SharedUI", tca]),

        .testTarget(name: "MarkdownWebViewTests", dependencies: ["MarkdownWebView"], resources: [.process("Resources")]),
        .testTarget(name: "APIClientLiveTests", dependencies: ["APIClientLive", "APIClient", "AppConfig", "Models"]),
        .testTarget(name: "LoginFeatureTests", dependencies: ["LoginFeature", "APIClient", "Models", tca]),
        .testTarget(name: "SidebarFeatureTests", dependencies: ["SidebarFeature", "APIClient", "Models", tca]),
        .testTarget(name: "CourseFeatureTests", dependencies: ["CourseFeature", "APIClient", "MarkdownWebView", "Models", tca]),
        .testTarget(name: "AppFeatureTests", dependencies: ["AppFeature", "LoginFeature", "SidebarFeature", "CourseFeature", "APIClient", "Models", tca]),
    ],
    swiftLanguageModes: [.v6]
)

// アプリ本体の Build Settings と揃える（CLAUDE.md「技術スタックと設定」）
for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
