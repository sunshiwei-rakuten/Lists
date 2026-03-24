// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ListKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "ListKit",
            targets: ["ListKit"]
        ),
    ],
    targets: [
        .target(
            name: "ListKit",
            path: "Sources/ListKit"
        ),
        .testTarget(
            name: "ListKitTests",
            dependencies: ["ListKit"],
            path: "Tests/ListKitTests"
        ),
    ]
)
