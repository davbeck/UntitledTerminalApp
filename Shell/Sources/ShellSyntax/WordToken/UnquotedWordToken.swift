import Foundation
import Parsing

public struct UnquotedWordToken: ParserPrinterSyntax {
	public var content: String

	public init(content: String) {
		self.content = content
	}

	static var parser: any ParserPrinter<ParserView, UnquotedWordToken> {
		UnquotedWordTokenParser()
	}
}

struct UnquotedWordTokenParser: ParserPrinter {
	var body: some ParserPrinter<ParserView, UnquotedWordToken> {
		Many(1..., into: "") { string, fragment in
			string.append(contentsOf: fragment)
		} decumulator: { string in
			string.map(String.init).reversed().makeIterator()
		} element: {
			OneOf {
				Prefix(1) { $0.isUnescapedUnquotedWordStringByte }.map(.string)

				// escaped character
				Parse {
					#"\"#.utf8

					OneOf {
						#"\"#.utf8.map { #"\"# }
						#"""#.utf8.map { #"""# }
						#" "#.utf8.map { #" "# }

						// escaping a character that doesn't need to be escaped is just the character
						Prefix(1) { $0.isUnescapedUnquotedWordStringByte }.map(.string)
					}
				}
			}
		} terminator: {
			Whitespace()
		}
		.map {
			UnquotedWordToken(content: $0)
		} reverse: {
			$0.content
		}
	}
}

private extension UTF8.CodeUnit {
	var isUnescapedUnquotedWordStringByte: Bool {
		self != .init(ascii: #"""#) && self != .init(ascii: #"\"#) && self > .init(ascii: " ")
	}
}
