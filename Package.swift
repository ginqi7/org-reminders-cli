// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "RemindersSync",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "reminders-sync", targets: ["remindersSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.3.1")),
        .package(url: "https://github.com/ginqi7/reminders-cli", branch: "main"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.4"),
    ],
    targets: [
        .executableTarget(
            name: "remindersSync",
            dependencies: [
                "SQLiteLibrary",
                .product(name: "RemindersLibrary", package: "reminders-cli"),
            ]
        ),
        .target(
            name: "SQLiteLibrary",
            dependencies: [
                "CommonLibrary",
                .product(name: "SQLite", package: "SQLite.swift"),
            ]
        ),
        .target(
            name: "CommonLibrary",
            dependencies: []
        ),
    ]
)
