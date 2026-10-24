// swift-tools-version:5.9
import PackageDescription

// build.sh compiles with swiftc directly; this manifest is for editing in Xcode (resources are copied by build.sh).
let package = Package(
    name: "Studymate",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Studymate",
            path: "Sources/Studymate"
        )
    ]
)
