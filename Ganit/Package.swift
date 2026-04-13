// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ganit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Ganit", targets: ["Ganit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "Ganit",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
            ],
            path: ".",
            exclude: ["Package.swift"],
            sources: [
                "App",
                "Core",
                "Features",
                "Shared",
            ]
        ),
    ]
)
