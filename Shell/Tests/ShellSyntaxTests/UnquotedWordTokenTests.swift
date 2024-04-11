import XCTest
@testable import ShellSyntax

final class UnquotedWordTokenTests: XCTestCase {
	func test_parse() throws {
		var input = "ls -a"[...].utf8
		let parsed = try UnquotedWordTokenParser().parse(&input)

		XCTAssertEqual(parsed.content, "ls")
		XCTAssertEqual(String(input), "-a")
	}

	func test_parse_escaped() throws {
		let input = #"hello\ \"world\""#
		let parsed = try UnquotedWordTokenParser().parse(input)

		XCTAssertEqual(parsed.content, #"hello "world""#)
	}

	func test_parse_escapedRegularCharacter() throws {
		let input = #"\thello"#
		let parsed = try UnquotedWordTokenParser().parse(input)

		XCTAssertEqual(parsed.content, #"thello"#)
	}
}
