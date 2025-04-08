// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "EditorConfig",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
		.tvOS(.v16),
		.watchOS(.v9),
		.macCatalyst(.v16),
		.visionOS(.v1),
	],
	products: [
		.library(name: "EditorConfig", targets: ["EditorConfig"]),
	],
	dependencies: [
		.package(url: "https://github.com/davbeck/swift-glob", from: "0.1.0"),
	],
	targets: [
		.target(
			name: "EditorConfig",
			dependencies: [.product(name: "Glob", package: "swift-glob")],
			swiftSettings: [.swiftLanguageMode(.v6)]
		),
		.testTarget(name: "EditorConfigTests", dependencies: ["EditorConfig"]),
	]
)
