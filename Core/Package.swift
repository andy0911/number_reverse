// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NumberOthelloCore",
    platforms: [.iOS("26.5"), .macOS(.v14)],
    products: [
        .library(name: "NumberOthelloCore", targets: ["NumberOthelloCore"]),
        .executable(name: "calibrate", targets: ["Calibrate"]),
    ],
    targets: [
        .target(name: "NumberOthelloCore"),
        // 難易度校正用の対戦シミュレーター（アプリには含めない。docs/calibration.md）
        .executableTarget(name: "Calibrate", dependencies: ["NumberOthelloCore"]),
        .testTarget(name: "NumberOthelloCoreTests", dependencies: ["NumberOthelloCore"]),
    ]
)
