// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalDictation",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LocalDictation", targets: ["LocalDictation"])],
    dependencies: [.package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.1"), .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.10.1")],
    targets: [
        .target(name: "DictationCore"),
        .executableTarget(name: "LocalDictation", dependencies: ["DictationCore", .product(name: "WhisperKit", package: "argmax-oss-swift"), .product(name: "Sparkle", package: "Sparkle")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "DictationCoreTests", dependencies: ["DictationCore"])
    ]
)
