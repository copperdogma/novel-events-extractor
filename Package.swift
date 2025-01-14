// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "novel-events-extractor",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NovelEventsExtractor",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "NovelEventsExtractorTests",
            dependencies: ["NovelEventsExtractor"],
            path: "Tests"
        )
    ]
)
