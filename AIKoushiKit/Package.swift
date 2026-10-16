// swift-tools-version: 6.2

import PackageDescription

// モジュールの分け方と依存の向きは ADR 0002。
// Feature とテストに APIClientLive を依存させない（本物の API を呼べない構造を保つため）。

let tca: Target.Dependency = .product(name: "ComposableArchitecture", package: "swift-composable-architecture")

let package = Package(
  name: "AIKoushiKit",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "APIClientLive", targets: ["APIClientLive"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2"),
  ],
  targets: [
    .target(name: "Models"),
    .target(name: "APIClient", dependencies: ["Models", tca]),
    .target(name: "APIClientLive", dependencies: ["APIClient", "Models"]),
    .target(name: "SharedUI", dependencies: ["Models"]),
    .target(name: "LoginFeature", dependencies: ["APIClient", "Models", tca]),
    .target(name: "SidebarFeature", dependencies: ["APIClient", "Models", "SharedUI", tca]),
    .target(name: "CourseFeature", dependencies: ["Models", "SharedUI", tca]),
    .target(name: "AppFeature", dependencies: ["LoginFeature", "SidebarFeature", "CourseFeature", "APIClient", "Models", "SharedUI", tca]),

    .testTarget(name: "LoginFeatureTests", dependencies: ["LoginFeature", "APIClient", "Models", tca]),
    .testTarget(name: "SidebarFeatureTests", dependencies: ["SidebarFeature", "APIClient", "Models", tca]),
    .testTarget(name: "CourseFeatureTests", dependencies: ["CourseFeature", "Models", tca]),
    .testTarget(name: "AppFeatureTests", dependencies: ["AppFeature", "APIClient", "Models", tca]),
  ],
  swiftLanguageModes: [.v6]
)

// アプリ本体の Build Settings と揃える（CLAUDE.md「技術スタックと設定」）
for target in package.targets {
  target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
