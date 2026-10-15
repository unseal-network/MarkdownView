// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MarkdownView", targets: ["MarkdownView"]),
    ],
    traits: [
        "LaTeX",
        .default(enabledTraits: ["LaTeX"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.2.1"),
        // Math typeset natively (CoreText), drawn synchronously: no JavaScript, no async height.
        .package(url: "https://github.com/mgriebling/SwiftMath.git", from: "1.7.3"),
    ],
    targets: [
        .target(
            name: "MarkdownView",
            dependencies: [
                .product(
                    name: "Markdown",
                    package: "swift-markdown"
                ),
                .product(
                    name: "Highlightr",
                    package: "Highlightr",
                    condition: .when(platforms: [.iOS, .macOS])
                ),
                // Not behind the LaTeX trait: Xcode does not pass a host's traits down to a nested
                // local package, so the math renderer would silently be compiled out.
                .product(
                    name: "SwiftMath",
                    package: "SwiftMath",
                    condition: .when(platforms: [.iOS, .macOS])
                ),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MarkdownViewTests",
            dependencies: [
                "MarkdownView",
            ]
        ),
    ]
)
