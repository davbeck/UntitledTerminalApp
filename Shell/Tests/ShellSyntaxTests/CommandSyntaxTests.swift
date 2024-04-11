import Foundation
import XCTest
@testable import ShellSyntax

final class CommandSyntaxTests: XCTestCase {
	func test_parse() throws {
		let input = "ls -a"
		let parsed = try CommandSyntax.parse(input)

		XCTAssertEqual(
			parsed,
			CommandSyntax(
				executable: .unquoted(.init(content: "ls")),
				arguments: [
					.unquoted(.init(content: "-a")),
				]
			)
		)
	}

	func test_parse_withoutArgs() throws {
		let input = "ls"
		let parsed = try CommandSyntax.parse(input)

		XCTAssertEqual(
			parsed,
			CommandSyntax(
				executable: .unquoted(.init(content: "ls")),
				arguments: []
			)
		)
	}
}
