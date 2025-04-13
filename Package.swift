// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "DeveloperExperienceSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "DeveloperExperienceSupport",
            targets: [
                "DeveloperExperienceSupport",
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vmanot/Merge.git", branch: "master"),
        .package(url: "https://github.com/vmanot/Swallow.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "DeveloperExperienceSupport",
            dependencies: [
                "Merge",
                "Swallow",
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "DeveloperExperienceSupportTests",
            dependencies: [
                "DeveloperExperienceSupport"
            ],
            path: "Tests/DeveloperExperienceSupport"
        )
    ]
)
