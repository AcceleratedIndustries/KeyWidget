// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KeyWidgetShared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KeyWidgetShared", targets: ["KeyWidgetShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "KeyWidgetShared",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "KeyWidgetSharedTests",
            dependencies: ["KeyWidgetShared"]
        ),
    ]
)
