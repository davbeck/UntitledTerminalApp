// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "ShellSyntax",
	platforms: [.macOS(.v14)],
	products: [
		.library(
			name: "ShellSyntax",
			targets: ["ShellSyntax"]
		),
		.library(
			name: "Shell",
			targets: ["Shell"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.13.0"),
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.1"),
		.package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.2.2"),
		.package(url: "https://github.com/pointfreeco/swift-concurrency-extras.git", from: "1.1.0"),
	],
	targets: [
		.target(
			name: "Shell",
			dependencies: [
				"ShellSyntax",
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "Dependencies", package: "swift-dependencies"),
				.product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency"),
			]
		),
		.target(
			name: "ShellSyntax",
			dependencies: [
				.product(name: "Parsing", package: "swift-parsing"),
			],
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency"),
			]
		),
		.testTarget(
			name: "ShellSyntaxTests",
			dependencies: ["ShellSyntax"]
		),
	]
)
