// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KaraDesk",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "KaraDesk", targets: ["KaraDesk"]),
    ],
    targets: [
        .target(
            name: "KaraDesk",
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "KaraDeskTests",
            dependencies: ["KaraDesk"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
