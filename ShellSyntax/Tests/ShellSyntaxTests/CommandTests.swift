import XCTest
@testable import Terminal

final class CommandTests: XCTestCase {
	func test_parse() throws {
		let command = Command.parse(#"echo test output"#)

		XCTAssertEqual(command, .executable(executable: "echo", arguments: ["test", "output"]))
	}
}
