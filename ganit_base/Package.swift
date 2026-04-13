import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .macOS(.v13), .windows(.v10_0)
    ],
    dependencies: [
        .package(url: "https://github.com/stackotter/swift-cross-ui.git", from: "0.1.0"),
        
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "KeychainAccess", package: "KeychainAccess")
            ]
        )
    ]
)

