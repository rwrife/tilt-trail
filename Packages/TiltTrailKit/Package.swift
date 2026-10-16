// swift-tools-version:6.0
import PackageDescription

// TiltTrailKit — pure-domain core for Tilt Trail.
// No UI, no networking, no Apple-only frameworks: Linux-testable by design.
let package = Package(
    name: "TiltTrailKit",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "TiltTrailKit", targets: ["TiltTrailKit"]),
    ],
    targets: [
        .target(name: "TiltTrailKit"),
        .testTarget(name: "TiltTrailKitTests", dependencies: ["TiltTrailKit"]),
    ]
)
