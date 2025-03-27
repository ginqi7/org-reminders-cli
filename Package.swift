// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "OrgReminders",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .executable(name: "org-reminders", targets: ["orgReminders"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.3.1")),
    .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", branch: "main"),
    .package(url: "https://github.com/ginqi7/tree-sitter-org", branch: "main"),
    .package(url: "https://github.com/ginqi7/reminders-cli", branch: "main"),
    .package(url: "https://github.com/ginqi7/websocket-bridge-swift", branch: "main"),
  ],
  targets: [
    .executableTarget(
      name: "orgReminders",
      dependencies: [
        "OrgLibrary",
        .product(name: "RemindersLibrary", package: "reminders-cli"),
        .product(name: "WebsocketBridgeLibrary", package: "websocket-bridge-swift"),
      ]
    ),
    .target(
      name: "OrgLibrary",
      dependencies: [
        "CommonLibrary",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
        .product(name: "TreeSitterOrg", package: "tree-sitter-org"),
      ]
    ),
    .target(
      name: "CommonLibrary",
      dependencies: []
    ),
  ]
)
