// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KeyWidgetShared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KeyWidgetShared", targets: ["KeyWidgetShared"]),
    ],
    targets: [
        .target(name: "KeyWidgetShared"),
    ]
)
