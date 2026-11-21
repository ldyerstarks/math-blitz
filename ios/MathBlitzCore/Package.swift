// swift-tools-version: 5.9
import PackageDescription

// MathBlitzCore is deliberately free of UIKit/SwiftUI so the scoring and
// lesson-picking rules can be unit-tested on any platform, including Linux CI.
let package = Package(
    name: "MathBlitzCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MathBlitzCore", targets: ["MathBlitzCore"])
    ],
    targets: [
        .target(name: "MathBlitzCore"),
        .testTarget(name: "MathBlitzCoreTests", dependencies: ["MathBlitzCore"])
    ]
)
