// swift-tools-version: 5.9
// XiulianCore：修練的所有規則（日期歸屬、打卡判定……）。
// 只能 import Foundation；CI 會在 macOS 上執行 `swift test --package-path XiulianCore`，測試沒過就不會編譯 app。
import PackageDescription

let package = Package(
    name: "XiulianCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "XiulianCore", targets: ["XiulianCore"]),
    ],
    targets: [
        .target(name: "XiulianCore"),
        .testTarget(name: "XiulianCoreTests", dependencies: ["XiulianCore"]),
    ]
)
