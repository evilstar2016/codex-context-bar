// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexContextBar",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexContextBar", targets: ["CodexContextBar"]),
        .library(name: "ContextCore", targets: ["ContextCore"]),
    ],
    dependencies: [.package(url: "https://github.com/dduan/TOMLDecoder.git", exact: "0.4.5")],
    targets: [
        .target(name: "ContextCore", dependencies: [.product(name: "TOMLDecoder", package: "TOMLDecoder")]),
        .executableTarget(name: "CodexContextBar", dependencies: ["ContextCore"], resources: [.process("Resources")]),
        .testTarget(name: "ContextCoreTests", dependencies: ["ContextCore"]),
        .testTarget(name: "InspectorTests", dependencies: ["CodexContextBar"]),
    ]
)
