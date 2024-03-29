//
//  TerminalTests.swift
//  TerminalTests
//
//  Created by David Beck on 3/27/24.
//

import XCTest
@testable import Terminal

final class CommandTests: XCTestCase {
	func test_parse() throws {
		let command = Command.parse(#"echo test output"#)
		
		XCTAssertEqual(command, .executable(executable: "echo", arguments: ["test", "output"]))
    }
}
