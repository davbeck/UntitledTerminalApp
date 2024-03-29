import Foundation

public enum Command: Equatable {
	case executable(executable: String, arguments: [String])
	case changeDirectory(path: String?)

	public var name: String {
		switch self {
		case let .executable(executable, _):
			executable
		case .changeDirectory:
			"cd"
		}
	}

	public static func parse(_ input: String) -> Command? {
		var tokens: [String] = []
		var currentToken = ""
		var quoteContext: Character?
		var i = input.startIndex
		while i < input.endIndex {
			let next = input[i]
			switch next {
			case "\\":
				i = input.index(after: i)
				currentToken.append(next)
			case " ":
				if quoteContext == nil {
					tokens.append(currentToken)
					currentToken = ""
				} else {
					currentToken.append(next)
				}
			case "\"":
				if quoteContext == "\"" {
					quoteContext = nil

					tokens.append(currentToken)
					currentToken = ""
				} else if quoteContext == nil {
					quoteContext = "\""
				} else {
					currentToken.append(next)
				}
			default:
				currentToken.append(next)
			}

			i = input.index(after: i)
		}

		tokens.append(currentToken)
		tokens.removeAll(where: { $0.isEmpty })

		guard let executable = tokens.first else { return nil }

		switch executable {
		case "cd":
			guard let path = tokens.dropFirst().last else { return nil }
			return .changeDirectory(path: path)
		default:
			return .executable(executable: executable, arguments: Array(tokens.dropFirst()))
		}
	}
}
