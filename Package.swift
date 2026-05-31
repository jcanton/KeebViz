// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeebViz",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "KeebViz", path: "Sources", resources: [.copy("Assets.xcassets")])]
)