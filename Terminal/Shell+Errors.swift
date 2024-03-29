import Foundation

protocol ShellError: Error {
	var feedOutput: String { get }
}

struct DirectoryDoesNotExist: Error {
	var path: String
}

extension DirectoryDoesNotExist: ShellError {
	var feedOutput: String {
		"The directory '\(path)' does not exist"
	}
}

struct NotADirectory: Error {
	var path: String
}

extension NotADirectory: ShellError {
	var feedOutput: String {
		"'\(path)' is not a directory"
	}
}

struct UnknownCommand: Error {
	var command: String
}

extension UnknownCommand: ShellError {
	var feedOutput: String {
		"Unknown command: \(command)"
	}
}
