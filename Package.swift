// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftMUD",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.20.0"),
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftMUD",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftMUDTests",
            dependencies: ["SwiftMUD"]
        ),
    ]
)
