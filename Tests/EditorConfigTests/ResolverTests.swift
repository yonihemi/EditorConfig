import XCTest
@testable import EditorConfig

final class ResolverTests: XCTestCase {
	lazy var tmpDir = FileManager.default
		.temporaryDirectory
		.appendingPathComponent("EditorConfigTests", isDirectory: true)

	override func setUp() async throws {
		try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
	}

	func testResolveSingleFile() throws {
		let rootConfig = Configuration(indentStyle: .tab)

		let configURL = tmpDir.appendingPathComponent(".editorconfig", isDirectory: false)

		try rootConfig
			.render(headerPattern: "*")
			.write(to: configURL, atomically: true, encoding: .utf8)

		let resolver = Resolver()

		let fileURL = tmpDir.appendingPathComponent("somefile")

		let configuration = try resolver.configuration(for: fileURL)

		XCTAssertEqual(configuration, rootConfig)
	}

	func testPatchnameMatching() throws {
		let resolver = Resolver()

		XCTAssertTrue(try resolver.matches("abc", pattern: "*"))

		XCTAssertTrue(try resolver.matches("abc.py", pattern: "*.py"))
		XCTAssertFalse(try resolver.matches("abc.js", pattern: "*.py"))

		XCTAssertTrue(try resolver.matches("Makefile", pattern: "Makefile"))
		XCTAssertFalse(try resolver.matches("Madefile", pattern: "Makefile"))
		XCTAssertFalse(try resolver.matches("abc/Mafefile", pattern: "Makefile"))

		XCTAssertTrue(try resolver.matches("lib/abc.js", pattern: "lib/**.js"))
		XCTAssertTrue(try resolver.matches("lib/a/bc.js", pattern: "lib/**.js"))
		XCTAssertFalse(try resolver.matches("lib/abc.py", pattern: "lib/**.js"))
		XCTAssertFalse(try resolver.matches("abc.js", pattern: "lib/**.js"))
		XCTAssertFalse(try resolver.matches("lid/abc.js", pattern: "lib/**.js"))
		XCTAssertFalse(try resolver.matches("libabc.js", pattern: "lib/**.js"))

		XCTAssertTrue(try resolver.matches("abc.js", pattern: "[ab]bc.js"))
		XCTAssertTrue(try resolver.matches("bbc.js", pattern: "[ab]bc.js"))
		XCTAssertFalse(try resolver.matches("cbc.js", pattern: "[ab]bc.js"))
		
		XCTAssertTrue(try resolver.matches("abc.js", pattern: "*.{js,py}"))
		XCTAssertTrue(try resolver.matches("abc.py", pattern: "*.{js,py}"))
		XCTAssertFalse(try resolver.matches("abc.txt", pattern: "*.{js,py}"))
		
		XCTAssertTrue(try resolver.matches("abc.js", pattern: "*.{js}"))
		XCTAssertFalse(try resolver.matches("abc.js", pattern: "*.{js,py"))
		XCTAssertFalse(try resolver.matches("abc.js", pattern: "*.js,py}"))

		XCTAssertTrue(try resolver.matches(".travis.yml", pattern: "{package.json,.travis.yml}"))
		XCTAssertFalse(try resolver.matches("config.json", pattern: "{package.json,.travis.yml}"))
		
		XCTAssertTrue(try resolver.matches("abc30.js", pattern: "abc{30..40}.js"))
		XCTAssertTrue(try resolver.matches("abc31.js", pattern: "abc{30..40}.js"))
		XCTAssertFalse(try resolver.matches("abc31.js", pattern: "abc{40..50}.js"))
		XCTAssertTrue(try resolver.matches("abc31def.js", pattern: "abc{30..40}def.js"))
		XCTAssertTrue(try resolver.matches("abc-31.js", pattern: "abc{-40..-30}.js"))
		
		XCTAssertTrue(try resolver.matches("abc31.js", pattern: "abc{30..40}.{js,py}"))
		XCTAssertFalse(try resolver.matches("abc31.js", pattern: "abc{40..50}.{js,py}"))
		
		XCTAssertThrowsError(try resolver.matches("abc31.js", pattern: "abc{30..20}.js"))
		XCTAssertThrowsError(try resolver.matches("abc31.js", pattern: "abc{30..30}.js"))
		XCTAssertFalse(try resolver.matches("abc31.js", pattern: "abc{30..40.js"))
		XCTAssertFalse(try resolver.matches("abc31.js", pattern: "abc30..40}.js"))
	}

	func testResolveSingleNonMatchingFile() throws {
		let rootConfig = Configuration(indentStyle: .tab)

		let configURL = tmpDir.appendingPathComponent(".editorconfig", isDirectory: false)

		try rootConfig
			.render(headerPattern: "*.js")
			.write(to: configURL, atomically: true, encoding: .utf8)

		let resolver = Resolver()

		let fileURL = tmpDir.appendingPathComponent("somefile.py", isDirectory: false)

		let configuration = try resolver.configuration(for: fileURL)

		XCTAssertEqual(configuration, Configuration())
	}

	func testResolveParentAndLocalConfiguration() throws {
		let rootConfig = Configuration(indentStyle: .tab, tabWidth: 4)

		let rootConfigURL = tmpDir.appendingPathComponent(".editorconfig", isDirectory: false)

		try rootConfig
			.render(headerPattern: "leaf/*.js")
			.write(to: rootConfigURL, atomically: true, encoding: .utf8)

		let leafConfig = Configuration(indentSize: 4, tabWidth: 2)

		let leafURL = tmpDir.appendingPathComponent("leaf", isDirectory: true)

		try FileManager.default.createDirectory(at: leafURL, withIntermediateDirectories: true)

		let leafConfigURL = leafURL.appendingPathComponent(".editorconfig", isDirectory: false)

		try leafConfig
			.render(headerPattern: "*.js")
			.write(to: leafConfigURL, atomically: true, encoding: .utf8)

		let fileURL = leafURL.appendingPathComponent("somefile.js", isDirectory: false)

		let resolver = Resolver()

		let configuration = try resolver.configuration(for: fileURL)

		XCTAssertEqual(configuration, Configuration(indentStyle: .tab, indentSize: 4, tabWidth: 2))
	}
}
