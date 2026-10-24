// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Studymate",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Studymate",
            path: "Sources/Studymate",
            resources: [
                .copy("../../Resources/KaTeX"),
                .copy("../../Resources/Content"),
            ]
        )
    ]
)
