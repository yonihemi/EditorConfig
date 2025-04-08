import Foundation
import Glob

public final class Resolver {
	enum Failure: Error {
		case unsupportedURL(URL)
		case noParentDirectories(URL)
		case invalidBracesPattern(String)
	}

	let limitURL: URL?
	private var contentCache = [URL: ConfigurationFileContent]()

	public init(limitURL: URL? = nil) {
		self.limitURL = limitURL
	}

	private func parentDirectories(for url: URL) throws -> [URL] {
		guard url.isFileURL else {
			throw Failure.unsupportedURL(url)
		}
		
		var components = url.pathComponents

		var urls = [URL]()

		while components.isEmpty == false {
			components.removeLast()
			if components.isEmpty {
				break
			}
			
			let path = components.joined(separator: "/")

			let url = URL(fileURLWithPath: path, isDirectory: true)

			if url == limitURL {
				break
			}

			urls.append(url)
		}

		return urls
	}

	private func configContent(at url: URL) throws -> ConfigurationFileContent {
		let text = try String(contentsOf: url)
		return try Parser().parse(text)
	}

	public func configuration(for url: URL) throws -> Configuration {
		guard url.isFileURL else {
			throw Failure.unsupportedURL(url)
		}

		let urls = try parentDirectories(for: url)
		let pathComponents = url.pathComponents

		let possibleConfigURLs = urls.map { $0.appendingPathComponent(".editorconfig", isDirectory: false) }.reversed()

		var config = Configuration()

		for configURL in possibleConfigURLs {
			guard FileManager.default.isReadableFile(atPath: configURL.path) else { continue }

			let configComponentCount = configURL.pathComponents.count - 1
			let relativeComponents = pathComponents.suffix(from: configComponentCount)
			let relativePath = relativeComponents.joined(separator: "/")

			let content = try configContent(at: configURL)
			let effectiveSections = try content.sections.filter({ try matches(relativePath, pattern: $0.pattern) })

			effectiveSections.forEach({ config.apply($0.configuration) })
		}

		return config
	}

	func matches(_ name: String, pattern: String) throws -> Bool {
		let patterns = try expandPatterns(pattern: pattern)
		for pattern in patterns {
			let patternMatcher = try Glob.Pattern(pattern, options: .default)
			if patternMatcher.match(name) {
				return true
			}
		}
		return false
	}
	
	private let bracePattern = #/\{([^{}]+)\}/#
	private func expandPatterns(pattern: String) throws -> [String] {
		guard let match = pattern.firstMatch(of: bracePattern) else {
			return [pattern]
		}
		
		let matchRange = match.range
		let contents = String(match.1)
		let expansion = try GlobExpansion(subpattern: contents)
		
		let expanded = expansion.expandedOptions.map { option in
			var newPattern = pattern
			newPattern.replaceSubrange(matchRange, with: option)
			return newPattern
		}
		
		return try expanded.flatMap { try expandPatterns(pattern: $0) }
	}
	
	enum GlobExpansion {
		/// `{s1,s2,s3}`
		/// Matches any of the strings given (separated by commas)
		case list([String])
		
		/// `{num1..num2}`
		/// Matches any integer numbers between num1 and num2, where num1 and num2 can be either positive or negative
		case range(ClosedRange<Int>)
		
		init(subpattern: String) throws {
			if subpattern.contains("..") {
				let components = subpattern.split(separator: "..").map { String($0) }
				guard components.count == 2,
					  let start = Int(components[0]),
					  let end = Int(components[1]),
					  start < end else {
					throw Resolver.Failure.invalidBracesPattern(subpattern)
				}
				self = .range(start...end)
			} else {
				let options = subpattern.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
				self = .list(options)
			}
		}
		
		var expandedOptions: [String] {
			switch self {
			case let .list(options):
				options
			case let .range(range):
				Array(range).map(String.init)
			}
		}
	}
}
