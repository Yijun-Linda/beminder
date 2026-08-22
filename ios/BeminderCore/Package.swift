// swift-tools-version: 6.0
// 纯逻辑 Swift Package，用于在 Windows / Linux 上用 swift test 验证
// beminder 的状态机与超时规则，摆脱对 Apple 框架与 Xcode 的依赖。
import PackageDescription

let package = Package(
    name: "BeminderCore",
    products: [
        .library(name: "BeminderCore", targets: ["BeminderCore"])
    ],
    targets: [
        .target(name: "BeminderCore"),
        .testTarget(name: "BeminderCoreTests", dependencies: ["BeminderCore"])
    ]
)