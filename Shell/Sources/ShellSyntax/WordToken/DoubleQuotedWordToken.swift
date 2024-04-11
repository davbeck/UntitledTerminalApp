import Foundation
import Parsing

// TODO: handle embeded variables and expressions

public struct DoubleQuotedWordToken: ParserPrinterSyntax {
	public var content: String

	public init(content: String) {
		self.content = content
	}

	static var parser: any ParserPrinter<ParserView, DoubleQuotedWordToken> {
		DoubleQuotedWordTokenParser()
	}
}

struct DoubleQuotedWordTokenParser: ParserPrinter {
	var body: some ParserPrinter<ParserView, DoubleQuotedWordToken> {
		Parse {
			"\"".utf8
			Many(into: "") { string, fragment in
				string.append(contentsOf: fragment)
			} decumulator: { string in
				string.map(String.init).reversed().makeIterator()
			} element: {
				OneOf {
					Prefix(1) { $0.isUnescapedDoubleQuotedWordStringByte }.map(.string)

					Parse {
						"\\".utf8

						OneOf {
							"\"".utf8.map { "\"" }
							"\\".utf8.map { "\\" }
							"/".utf8.map { "/" }
							"b".utf8.map { "\u{8}" }
							"f".utf8.map { "\u{c}" }
							"n".utf8.map { "\n" }
							"r".utf8.map { "\r" }
							"t".utf8.map { "\t" }
							//				ParsePrint(.unicode) {
							//					Prefix(4) { $0.isHexDigit }
							//				}
						}
					}
				}
			} terminator: {
				"\"".utf8
			}
		}
		.map {
			DoubleQuotedWordToken(content: $0)
		} reverse: {
			$0.content
		}
	}
}

private extension UTF8.CodeUnit {
	var isUnescapedDoubleQuotedWordStringByte: Bool {
		self != .init(ascii: #"""#) && self != .init(ascii: #"\"#) && self >= .init(ascii: " ")
	}
}
