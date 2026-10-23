// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VocaDayCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VocaDayCore", targets: ["VocaDayCore"]),
    ],
    targets: [
        .target(name: "VocaDayCore"),
        .testTarget(
            name: "VocaDayCoreTests",
            dependencies: ["VocaDayCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
