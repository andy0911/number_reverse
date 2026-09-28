// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NumberOthelloCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NumberOthelloCore", targets: ["NumberOthelloCore"]),
    ],
    targets: [
        .target(name: "NumberOthelloCore"),
        .testTarget(name: "NumberOthelloCoreTests", dependencies: ["NumberOthelloCore"]),
    ]
)
