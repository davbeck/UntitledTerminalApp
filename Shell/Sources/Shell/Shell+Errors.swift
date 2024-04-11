import Foundation

protocol ShellError: Error {
	var feedOutput: String { get }
}

extension Error {
	var _feedOutput: String {
		if let self = self as? ShellError {
			return self.feedOutput
		} else {
			return self.localizedDescription
		}
	}
}

struct UnknownCommand: ShellError {
	var command: String
	
	var feedOutput: String {
		"Unknown command \(command)"
	}
}

struct ParseError: ShellError {
	var underlyingError: Error
	
	var feedOutput: String {
		"Failed to parse input: \(underlyingError._feedOutput)"
	}
}
